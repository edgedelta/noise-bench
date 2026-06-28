#!/bin/bash
# Oracle solution: write the known-correct triage decisions for node-event-noise.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "Real NodeNotReady SEV1: node ip-10-0-7-44 node_ready dropped 1->0 at 22:40 and stayed 0 through 23:00, pat-node-notready +700% negative, never auto-resolved. Genuine capacity loss. Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "DisruptionBlocked, PDB protecting streaming taskmanagers. pat-pdb-block delta 0%, neutral, recurring 6x/hr. Normal Karpenter/PDB operational meta-event."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "DisruptionBlocked, same pat-pdb-block (delta 0%, neutral, 6x/hr). Operational meta-event."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "Unconsolidatable NodePool nodepool-olapdb, pat-unconsolidatable delta 0% neutral. Expected Karpenter config event."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "SpotToSpotConsolidation disabled, pat-spot-consol delta 0% neutral. Normal NodePool config."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "store validated, pat-store-validated delta 0% neutral. Routine validation event."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "DisruptionBlocked, pat-pdb-block delta 0% neutral. Operational meta-event."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "Unconsolidatable, pat-unconsolidatable delta 0% neutral. Expected Karpenter event."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "SpotToSpotConsolidation disabled, pat-spot-consol delta 0% neutral. NodePool config."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "store validated, pat-store-validated delta 0% neutral. Routine."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "DisruptionBlocked, pat-pdb-block delta 0% neutral. Operational meta-event."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "Unconsolidatable, pat-unconsolidatable delta 0% neutral. Expected Karpenter event."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor: 17 fires/hr, auto_resolved_after_s 20, pat-log-threshold delta 0%. Chronic flapper."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "SpotToSpotConsolidation disabled, pat-spot-consol delta 0% neutral. NodePool config."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "store validated, pat-store-validated delta 0% neutral. Routine."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "DisruptionBlocked, pat-pdb-block delta 0% neutral. Operational meta-event."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor: 19 fires/hr, auto_resolved_after_s 18, delta 0%. Flapper."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "scheduling_pending_pods=7 at 22:43, related_pattern pat-node-notready, onset minutes after P01. Downstream symptom of the NodeNotReady capacity loss. Collapse into P01."
    },
    {
      "page_id": "P19",
      "decision": "page",
      "reason": "Real CrashLoopBackOff on checkout-api: 11 restarts vs threshold 3, pat-checkout-crashloop +1400% negative (nil-pointer panic in PaymentHandler), onset 21:54 right after deploy checkout-api@2026.06.19-4 at 21:52, never auto-resolves, available_replicas fell 3->1 (below min 3). Deploy-induced outage. Page (root of the checkout incident)."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "available_replicas=1 (below threshold 3) at 21:58, related_pattern pat-checkout-crashloop, same deploy and onset as P19. Downstream symptom. Collapse into P19."
    },
    {
      "page_id": "P21",
      "decision": "page",
      "reason": "Real node MemoryPressure eviction SEV1: ip-10-0-9-21 node_memory_available_pct fell 18->3 at 22:05 and stayed ~4, evicting ingest-gateway pods, pat-mempressure-evict +900% negative, never auto-resolves. Cardinal must-page."
    },
    {
      "page_id": "P22",
      "decision": "suppress",
      "reason": "http_5xx_rate 38.4 (threshold 2) at 22:08, related_pattern pat-mempressure-evict, onset minutes after P21. Customer-facing symptom of the eviction. Collapse into P21."
    },
    {
      "page_id": "P23",
      "decision": "suppress",
      "reason": "billing-worker crashloop is a flapper: fired_count_last_1h 14, auto_resolved_after_s 35, pat-billing-restart delta 0% neutral, available_replicas recovered 4->5 immediately. Self-healing readiness restarts, not an outage."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — node-event-noise

Three real, page-class incidents are buried among Karpenter/PDB operational meta-noise:

1. **P01 — NodeNotReady (SEV1, must-page).** node_ready on ip-10-0-7-44 went 1->0 at 22:40
   and stayed 0; pat-node-notready surging +700% negative; never auto-resolved. **P18**
   (pending pods at 22:43, same pat-node-notready) is its downstream symptom — collapse into P01.

2. **P19 — checkout-api CrashLoopBackOff (deploy-induced).** 11 restarts vs threshold 3,
   pat-checkout-crashloop +1400% negative (nil-pointer panic in PaymentHandler), onset 21:54
   immediately after deploy checkout-api@2026.06.19-4 (21:52). available_replicas fell 3->1,
   below min 3, and stayed there — service degraded, never self-heals. **P20** (available_replicas
   below min, same pattern/deploy) is the same incident — collapse into P19.

3. **P21 — node MemoryPressure eviction (SEV1, must-page).** ip-10-0-9-21 memory fell to ~3%,
   evicting ingest-gateway; pat-mempressure-evict +900% negative; never auto-resolves. **P22**
   (http_5xx_rate 38.4, customer-facing) is the symptom — collapse into P21.

Everything else is noise expressed through its features:
- **Karpenter/PDB operational meta-events** (P02-P12, P14-P16): DisruptionBlocked, Unconsolidatable,
  SpotToSpotConsolidation disabled, store validated — all delta_vs_baseline_pct 0, neutral sentiment,
  recurring multiple times/hr.
- **[ignore] log-threshold flappers** (P13, P17): high fired_count, auto-resolve in <20s.
- **P23 billing-worker crashloop (precision trap)**: crashloop-shaped and deploy-correlated like P19,
  but auto_resolves in 35s, fires 14x/hr, pat-billing-restart delta 0% neutral, and available_replicas
  recovered 4->5 immediately. A flapping readiness-probe restart, not an outage.

See `tests/ground_truth.json` for per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
