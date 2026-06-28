#!/usr/bin/env python3
"""
Structural validator for ComfyUI workflow JSON files.
Checks link consistency, node references, and optionally queries
a running ComfyUI server to verify node types are registered.

Usage:
    python validate_workflows.py                  # validate all known workflows
    python validate_workflows.py path/to/wf.json  # validate specific file(s)
    python validate_workflows.py --check-server   # also query ComfyUI for node types
"""
import json
import sys
import urllib.request
from pathlib import Path

WORKFLOWS_DIR = Path("/mnt/c/ai_tools/comfyui-rocm/user/default/workflows")
SERVER = "http://127.0.0.1:8189"

KNOWN_WORKFLOWS = sorted(WORKFLOWS_DIR.glob("rocm_r9700_*.json"))

# Node types that are expected to be registered (core + our custom nodes)
KNOWN_NODE_TYPES = {
    # ComfyUI core
    "CheckpointLoaderSimple", "UNETLoader", "UnetLoaderGGUF",
    "CLIPLoader", "DualCLIPLoader", "VAELoader",
    "CLIPTextEncode", "EmptyLatentImage", "EmptySD3LatentImage",
    "KSampler", "KSamplerSelect", "SamplerCustomAdvanced",
    "BasicScheduler", "BasicGuider", "CFGGuider",
    "FluxGuidance", "RandomNoise",
    "VAEDecode", "VAEDecodeTiled", "SaveImage", "LoadImage",
    "ModelSamplingAuraFlow",
    # ComfyUI core LTX (nodes_lt.py)
    "LTXVImgToVideo", "LTXVImgToVideoInplace",
    "LTXVAddGuide", "LTXVCropGuides",
    "LTXVConditioning", "LTXVScheduler", "LTXVPreprocess",
    "EmptyLTXVLatentVideo", "ModelSamplingLTXV",
    # ComfyUI core LTX audio (nodes_lt_audio.py)
    "LTXAVTextEncoderLoader",
    # ComfyUI-LTXVideo custom nodes
    "LTXVImgToVideoAdvanced", "LTXVAddGuideAdvanced",
    "LTXVAddGuideAdvancedAttention", "LTXVTiledVAEDecode",
    "LTXVSelectLatents", "LTXVApplySTG", "LTXVBaseSampler",
    "LTXVGemmaCLIPModelLoader",
    # ComfyUI-VideoHelperSuite
    "VHS_VideoCombine", "VHS_LoadVideo",
}


def validate_workflow(path: Path, server_nodes: set | None = None) -> list[str]:
    """Returns list of error strings. Empty = valid."""
    errors = []
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        return [f"JSON parse error: {e}"]

    nodes = {n["id"]: n for n in data.get("nodes", [])}
    links_list = data.get("links", [])
    last_node_id = data.get("last_node_id", 0)
    last_link_id = data.get("last_link_id", 0)

    # Build link map: link_id → [from_node, from_slot, to_node, to_slot, type_str]
    link_map: dict[int, list] = {}
    seen_link_ids: set[int] = set()

    for entry in links_list:
        if len(entry) < 6:
            errors.append(f"Malformed link entry (need 6 fields): {entry}")
            continue
        lid, from_node, from_slot, to_node, to_slot, type_str = entry[:6]
        if lid in seen_link_ids:
            errors.append(f"Duplicate link ID {lid}")
        seen_link_ids.add(lid)
        link_map[lid] = [from_node, from_slot, to_node, to_slot, type_str]

    max_link_id = max(seen_link_ids) if seen_link_ids else 0
    if last_link_id < max_link_id:
        errors.append(f"last_link_id={last_link_id} < max link ID {max_link_id}")

    max_node_id = max(nodes) if nodes else 0
    if last_node_id < max_node_id:
        errors.append(f"last_node_id={last_node_id} < max node ID {max_node_id}")

    # Validate each link's node references
    for lid, (from_node, from_slot, to_node, to_slot, _) in link_map.items():
        if from_node not in nodes:
            errors.append(f"Link {lid}: from_node {from_node} does not exist")
        if to_node not in nodes:
            errors.append(f"Link {lid}: to_node {to_node} does not exist")

    # Validate each node's declared outputs reference valid link IDs
    for nid, node in nodes.items():
        ntype = node.get("type", "?")

        # Check node type is known
        if server_nodes is not None:
            if ntype not in server_nodes:
                errors.append(f"Node {nid} ({ntype}): NOT registered in ComfyUI server")
        else:
            if ntype not in KNOWN_NODE_TYPES:
                errors.append(f"Node {nid} ({ntype}): unknown type (not in KNOWN_NODE_TYPES)")

        # Validate output link references
        for slot_idx, output in enumerate(node.get("outputs", [])):
            out_links = output.get("links") or []
            for lid in out_links:
                if lid not in link_map:
                    errors.append(f"Node {nid} ({ntype}) output slot {slot_idx}: references link {lid} not in links array")
                else:
                    fn, fs, tn, ts, _ = link_map[lid]
                    if fn != nid:
                        errors.append(f"Link {lid}: from_node {fn} != node {nid} (output declares it)")
                    if fs != slot_idx:
                        errors.append(f"Link {lid}: from_slot {fs} != slot_index {slot_idx} in node {nid} output")

        # Validate input link references
        for slot_idx, inp in enumerate(node.get("inputs", [])):
            lid = inp.get("link")
            if lid is None:
                continue
            if lid not in link_map:
                errors.append(f"Node {nid} ({ntype}) input slot {slot_idx} ({inp.get('name')}): references link {lid} not in links array")
            else:
                fn, fs, tn, ts, _ = link_map[lid]
                if tn != nid:
                    errors.append(f"Link {lid}: to_node {tn} != node {nid} (input declares it)")
                if ts != slot_idx:
                    errors.append(f"Link {lid}: to_slot {ts} != slot index {slot_idx} in node {nid} input '{inp.get('name')}'")

    # Check every link is referenced by both its source and target node
    for lid, (from_node, from_slot, to_node, to_slot, _) in link_map.items():
        if from_node in nodes:
            outputs = nodes[from_node].get("outputs", [])
            if from_slot < len(outputs):
                out_links = outputs[from_slot].get("links") or []
                if lid not in out_links:
                    errors.append(f"Link {lid}: from_node {from_node} slot {from_slot} does not list this link in its outputs")
            else:
                errors.append(f"Link {lid}: from_slot {from_slot} out of range for node {from_node} ({len(outputs)} outputs)")

        if to_node in nodes:
            inputs = nodes[to_node].get("inputs", [])
            if to_slot < len(inputs):
                inp_link = inputs[to_slot].get("link")
                if inp_link != lid:
                    errors.append(f"Link {lid}: to_node {to_node} slot {to_slot} has link={inp_link}, expected {lid}")
            else:
                errors.append(f"Link {lid}: to_slot {to_slot} out of range for node {to_node} ({len(inputs)} inputs)")

    return errors


def get_server_nodes() -> set | None:
    try:
        with urllib.request.urlopen(f"{SERVER}/object_info", timeout=5) as resp:
            info = json.loads(resp.read())
            return set(info.keys())
    except Exception:
        return None


def main():
    args = sys.argv[1:]
    check_server = "--check-server" in args
    file_args = [a for a in args if not a.startswith("--")]

    if file_args:
        targets = [Path(p) for p in file_args]
    else:
        targets = list(KNOWN_WORKFLOWS)

    if not targets:
        print("No workflow files found.")
        return 0

    server_nodes = None
    if check_server:
        print(f"Querying ComfyUI at {SERVER} for registered nodes...", end=" ", flush=True)
        server_nodes = get_server_nodes()
        if server_nodes:
            print(f"OK ({len(server_nodes)} node types registered)")
        else:
            print("UNREACHABLE — skipping server node checks")

    total = 0
    failed = 0
    print()

    for path in targets:
        if not path.exists():
            print(f"  ✗ {path.name}: FILE NOT FOUND")
            failed += 1
            total += 1
            continue

        errors = validate_workflow(path, server_nodes)
        total += 1

        if errors:
            failed += 1
            print(f"  ✗ {path.name}: {len(errors)} error(s)")
            for e in errors:
                print(f"      - {e}")
        else:
            data = json.loads(path.read_text())
            n_nodes = len(data.get("nodes", []))
            n_links = len(data.get("links", []))
            print(f"  ✓ {path.name}  ({n_nodes} nodes, {n_links} links)")

    print(f"\n{total - failed}/{total} workflows valid")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
