"""Turn `nix build --log-format internal-json` output into a Chrome trace for Perfetto.

Usage: nix build --log-format internal-json ... 2>&1 | python3 nix-build-trace.py OUT.json

Nix's events carry no timestamps, so each one is stamped as it arrives. Nix's own
messages are printed to stderr as plain text, so the build log stays readable.
"""

import json
import re
import sys
import time

# Activity and result types from Nix's logging.hh.
BUILD, SUBSTITUTE, COPY_PATH, FILE_TRANSFER, QUERY_PATH_INFO = 105, 108, 100, 101, 109
UMBRELLA = {102: "realise", 103: "copy paths", 104: "builds"}
RESULT_SET_PHASE = 104
RESULT_PROGRESS = 105
INFO = 3

STORE_PATH = re.compile(r"/nix/store/[0-9a-z]{32}-([^'/\s]+?)(\.drv)?(?=['\s]|$)")
STORE_HASH = re.compile(r"/nix/store/[0-9a-z]{32}-")


def short(path):
    m = STORE_PATH.search(path)
    return m.group(1) if m else path


def name_of(act):
    fields = act.get("fields") or []
    t = act["type"]
    if t == BUILD:
        return "build " + short(fields[0])
    if t == SUBSTITUTE:
        return "substitute " + short(fields[0])
    if t == COPY_PATH:
        return "copy " + short(fields[0])
    if t == FILE_TRANSFER:
        return "download " + fields[0].rsplit("/", 1)[-1]
    if t == QUERY_PATH_INFO:
        return "query " + short(fields[0])
    if t in UMBRELLA:
        return UMBRELLA[t]
    return STORE_HASH.sub("", act.get("text") or "") or f"activity {t}"


def assign_lanes(spans):
    """Give each span a lane (Perfetto thread) where it nests properly.

    Spans on one lane must either not overlap or be fully contained in one another,
    so overlapping work is spread across lanes. A span goes on its parent's lane when
    it fits there, so children are drawn under their parent.
    """
    stacks = []  # per lane: open spans, outermost first
    by_id = {}
    for s in sorted(spans, key=lambda s: (s["ts"], -s["end"])):

        def fits(lane):
            stack = stacks[lane]
            while stack and stack[-1]["end"] <= s["ts"]:
                stack.pop()
            return not stack or stack[-1]["end"] >= s["end"]

        parent = by_id.get(s["parent"])
        order = ([parent["lane"]] if parent else []) + list(range(len(stacks)))
        lane = next((n for n in order if fits(n)), None)
        if lane is None:
            stacks.append([])
            lane = len(stacks) - 1
        s["lane"] = lane
        stacks[lane].append(s)
        if s["id"] is not None:
            by_id[s["id"]] = s
    return len(stacks)


def main():
    out = sys.argv[1]
    start = time.monotonic_ns()
    # Whole microseconds, so start + duration converts to nanoseconds exactly.
    now = lambda: (time.monotonic_ns() - start) // 1000

    open_acts, phases, spans = {}, {}, []

    def close_phase(act_id, ts):
        phase = phases.pop(act_id, None)
        if phase:
            phase["end"] = ts
            spans.append(phase)

    for line in iter(sys.stdin.readline, ""):
        if not line.startswith("@nix "):
            sys.stderr.write(line)
            continue
        # Progress updates are most of the stream and carry nothing the trace uses.
        # Build activities are type 105 too, so match only the result action.
        if line.startswith('@nix {"action":"result"') and line.rstrip().endswith(
            f'"type":{RESULT_PROGRESS}}}'
        ):
            continue
        ts = now()
        ev = json.loads(line[5:])
        action = ev["action"]
        if action == "msg":
            if ev["level"] <= INFO:
                sys.stderr.write(ev["msg"] + "\n")
        elif action == "start":
            ev["ts"] = ts
            open_acts[ev["id"]] = ev
        elif action == "result" and ev["type"] == RESULT_SET_PHASE and ev["id"] in open_acts:
            close_phase(ev["id"], ts)
            phases[ev["id"]] = {
                "name": ev["fields"][0],
                "cat": "phase",
                "ts": ts,
                "id": None,
                "parent": ev["id"],
            }
        elif action == "stop" and ev["id"] in open_acts:
            act = open_acts.pop(ev["id"])
            close_phase(act["id"], ts)
            spans.append(
                {
                    "name": name_of(act),
                    "cat": str(act["type"]),
                    "ts": act["ts"],
                    "end": ts,
                    "id": act["id"],
                    "parent": act.get("parent") or None,
                }
            )

    # Anything still open when Nix exited (a failed build, for example) ends here.
    end = now()
    for act_id in list(phases):
        close_phase(act_id, end)
    for act in open_acts.values():
        spans.append(
            {
                "name": name_of(act),
                "cat": str(act["type"]),
                "ts": act["ts"],
                "end": end,
                "id": act["id"],
                "parent": act.get("parent") or None,
                "unfinished": True,
            }
        )

    lanes = assign_lanes(spans)
    # Perfetto merges a thread whose ID is 0 or equals the process ID (1) into the
    # process's main thread, which would put two lanes on one track.
    tid = lambda lane: lane + 2
    events = [{"ph": "M", "pid": 1, "name": "process_name", "args": {"name": "nix build"}}]
    events += [
        {"ph": "M", "pid": 1, "tid": tid(n), "name": "thread_name", "args": {"name": f"lane {n}"}}
        for n in range(lanes)
    ]
    events += [
        {
            "ph": "X",
            "pid": 1,
            "tid": tid(s["lane"]),
            "name": s["name"],
            "cat": s["cat"],
            "ts": s["ts"],
            "dur": s["end"] - s["ts"],
            # Speedscope appends args to span names, so only the failure marker is kept.
            **({"args": {"unfinished": True}} if s.get("unfinished") else {}),
        }
        for s in spans
    ]
    with open(out, "w") as f:
        json.dump({"traceEvents": events, "displayTimeUnit": "ms"}, f)


if __name__ == "__main__":
    main()
