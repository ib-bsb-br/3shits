# Framework3: TreeSheets Primitives, Invariants, and Behavioral Contracts

## 0) Purpose and Link to Framework1

`framework3` is an explicit **extension** of `framework1`, not a replacement.

- `framework1` gives a **positional sibling mapping grammar** (`L#...`, `C..L...`, `sibling_OF`, recursive dot paths).
- `framework3` preserves that grammar as its **Axis A (Structural Addressing)** and adds:
  - **Axis B (State Invariants)** derived from TreeSheets internals.
  - **Axis C (Behavioral Contracts)** for operations that mutate cells/grids/documents.

So the new relationship is:

```text
framework3 = framework1 (address/topology) + invariants (valid states) + contracts (valid transitions)
```

---

## 1) Analysis of Framework1 (Core Principles, Structure, Components)

### 1.1 What framework1 is doing

From the provided notation, `framework1` encodes a recursive rule system where:

1. A line index (`L#n`, `L#n-01`, `L#01+n`) maps to an identifier (`id(C01L...)`).
2. The same rule is re-applied **within a parent-qualified namespace** such as `(C01L#n).(C01L_)`.
3. There is a visible hierarchical expansion in the ASCII tree sample:
   - `C01L___01`
   - `C01L01.C01L___01`
   - `C01L01.C01L___02` etc.

### 1.2 Core principles extracted from framework1

- **Sibling-relative semantics**: entities are located by sibling relations, not only absolute coordinates.
- **Recursive composability**: address fragments can be chained (`A.B.C`) to represent nested levels.
- **Dual-scale consistency**: top-level and nested-level rules follow the same pattern.
- **Index transform semantics**: `(n-01, n, 01+n)` implies predecessor/current/successor traversal logic.

### 1.3 Limitation of framework1 (why extension is needed)

`framework1` is strong at **where a node is**, but weak at:

- what states are legal at that node,
- what mutations are legal,
- what must happen before/after a mutation.

That is exactly what raw TreeSheets source can supply.

---

## 2) Raw Data Examination (TreeSheets Source Concepts)

Using TreeSheets/3shits source, the following primitives and rules are explicit.

### 2.1 Primitive model

- `Cell` is the main node primitive with:
  - parent pointer,
  - text payload,
  - optional child grid,
  - style/render attributes. (`src/cell.h`).
- `Grid` is a 2D container primitive with:
  - owner cell,
  - cell matrix (`xs`, `ys`, `cells`),
  - column widths and layout properties. (`src/grid.h`).
- `Selection` is a scoped operation primitive:
  - target grid + rectangular bounds + text cursor/edit state. (`src/selection.h`).
- `Document` is the root/system primitive:
  - root cell, selected/hover state, undo/redo history, draw path. (`src/document.h`).

### 2.2 Invariants already encoded in code

Representative invariants in source include:

- Grid coordinate safety (`C(x,y)` bounds assertion).
- Parent-child consistency (`c->parent` assignments on insertion/merge/reparent).
- Structural mutation shape rules in insertion (`nxs + nys == 1` etc.).
- Selection validity checks (grid existence, bounds confinement).
- Undo-before-mutation discipline in many mutating APIs.
- Script mutation guardrails (`max_new_grid_cells`, range checks).

### 2.3 Behavioral contracts implicit in methods

Source shows stable pre/post patterns:

- **Preconditions**: exists parent/grid, in-range coordinates, allowed size.
- **State transition**: modify cell/grid/document structure.
- **Postconditions**: reset layout lineage, refresh canvas, maintain selection or zoom.

This is visible in operations such as `InsertCells`, `MultiCellDeleteSub`, selection movement/edit actions, and script interface mutators.

---

## 3) Integration Strategy (How raw data extends framework1)

### 3.1 Three-axis synthesis

We attach two new dimensions to framework1:

1. **Axis A — Structural Addressing (from framework1)**  
   Path identity via sibling-recursive grammar.
2. **Axis B — State Invariants (from raw code)**  
   Conditions that must always hold for any valid TreeSheets state.
3. **Axis C — Behavioral Contracts (from raw code)**  
   Transition rules for each mutating operation.

### 3.2 Mapping table

| Framework1 element | Raw-data augmentation | Framework3 result |
|---|---|---|
| `id(C..L..)` lineage path | `Cell`/`Grid` pointer topology | Path + runtime object identity |
| Sibling relation rules | `Grid::C(x,y)`, selection bounds | Address validated by coordinate contracts |
| Recursive nesting | `Cell.grid`, `parent` recursion | Typed hierarchical state graph |
| Implicit transitions (`n-1`, `n`, `n+1`) | Insert/delete/move APIs | Formal transition contracts |

---

## 4) Draft Framework3 (v0.9)

## 4.1 Formal object model

Let:

- `D` = document
- `R` = root cell
- `G` = grid
- `C` = cell
- `S` = selection
- `P(C)` = framework1-style path identity for `C`

### 4.1.1 Primitive types

```text
Cell C := {
  parent: Cell?;
  text: Text;
  grid: Grid?;
  style: StyleState;
}

Grid G := {
  cell: Cell;                // owner
  xs, ys: int > 0;
  cells: Cell[xs * ys];
  colwidths: int[xs];
  folded: bool;
}

Selection S := {
  grid: Grid?;
  x,y,xs,ys: int;
  textedit: bool;
  cursor,cursorend: int;
}

Document D := {
  root: Cell;
  selected, hover: Selection;
  undolist, redolist;
  drawpath;
}
```

### 4.1.2 Path identity (preserve framework1)

```text
P(C) ::= framework1 sibling-recursive id expression
       | RootSegment(.ChildSegment)*
```

Operational interpretation:
- framework1 textual IDs remain canonical for logical navigation.
- runtime path can be resolved to `(grid, x, y)` and object pointer identity.

## 4.2 Global invariants (I)

### I1 — Coordinate Safety
For any `G`, `0 <= x < G.xs` and `0 <= y < G.ys` before dereference.

### I2 — Parent/Owner Consistency
For every child `c` in `G.cells`, `c.parent == G.cell`.

### I3 — Grid Shape Consistency
`len(G.cells) == G.xs * G.ys` and `len(G.colwidths) == G.xs`.

### I4 — Selection Validity
If `S.grid != null`, then `0 <= S.x`, `0 <= S.y`, and `S.x + S.xs <= grid.xs`, `S.y + S.ys <= grid.ys`.

### I5 — Undo Protection on Mutation
Every user-visible mutation must be preceded by undo capture at the appropriate LCA scope.

### I6 — Fold Visibility Safety
If path navigation lands inside folded ancestry, fold state must be reconciled (unfold/zoom logic) before interaction.

### I7 — Bounded Construction
New grid creation obeys bounded product (`x*y < max_new_grid_cells`) in script/API contract surface.

## 4.3 Behavioral contracts (C)

Contracts are expressed as:

```text
OperationName
  PRE: ...
  TRANSFORM: ...
  POST: ...
  FAILSAFE: ...
```

### C1 — CreateGrid(x, y)
- PRE: current cell exists, `x>0`, `y>0`, `x*y < MAX`.
- TRANSFORM: attach new grid to current cell.
- POST: parent/owner consistency holds; undo recorded.
- FAILSAFE: if precondition fails, no mutation.

### C2 — InsertColumn/InsertRow
- PRE: target has grid; insertion index in `[0..xs]` or `[0..ys]`.
- TRANSFORM: reshape matrix by one axis; initialize inserted cells with inherited style basis.
- POST: shape invariants hold (`I3`), orientation recomputed.
- FAILSAFE: no-op when invalid index/grid absent.

### C3 — DeleteRegion(x,y,xs,ys)
- PRE: target bounds fully inside grid.
- TRANSFORM: clear selected cells; optionally collapse row/column or delete owning subgrid.
- POST: selection normalized or cleared; canvas/view updated.
- FAILSAFE: root-protection branch prevents illegal root destruction.

### C4 — MoveSelection(dx,dy)
- PRE: non-text selection mode and valid grid.
- TRANSFORM: cyclic swap/move across selection extents.
- POST: selection coordinates wrapped; if out-of-range after resize, selection nullified.
- FAILSAFE: no structural corruption on boundary crossing.

### C5 — SetText/SetNote/Style/Color
- PRE: editable target exists (often non-root constraint by parent existence).
- TRANSFORM: mutate scalar properties.
- POST: descendants/layout invalidation if needed; undo lineage preserved.
- FAILSAFE: disallow mutation when preconditions absent.

### C6 — MergeWithParent
- PRE: child grid + parent grid exist.
- TRANSFORM: promote child cells into parent with conflict-resolving insertion expansion.
- POST: reparent every moved cell; selection and edit mode reconciled.
- FAILSAFE: ownership transferred without double-delete.

## 4.4 Framework1 compatibility layer

To keep direct lineage with framework1, every operation logs/accepts a **PathContext**:

```text
PathContext := {
  logical_id: framework1-id-string,
  resolved_grid: Grid*,
  resolved_coord: (x,y),
  depth,
  sibling_index
}
```

All contracts in 4.3 apply to `PathContext.resolved_*`, while retaining `logical_id` for tracing and audit.

---

## 5) Evaluation of Draft (coherence, completeness, clarity, practicality)

### 5.1 Coherence

High coherence: the model uses one stable chain:

`framework1 path grammar -> resolved runtime node -> invariant check -> contracted mutation`.

### 5.2 Completeness

Covers:
- primitives (`Cell/Grid/Selection/Document`),
- persistent invariants,
- high-frequency mutation contracts,
- script and UI mutation surfaces.

Gap left intentionally: concurrent editing and multi-user replication semantics (not native in TreeSheets core).

### 5.3 Clarity

Improved over framework1 because each symbolic address now has:
- a runtime resolution mechanism,
- explicit legal-state conditions,
- explicit pre/post operation guarantees.

### 5.4 Practicality

Practical because it can be implemented incrementally:
1. add lightweight invariant assertions,
2. add contract-check helper macros,
3. add path-context logging in mutators.

### 5.5 Comparison with established frameworks

- **Design by Contract (DbC):** framework3 now matches DbC style (`PRE/POST/INVARIANT`) while preserving TreeSheets domain syntax.
- **Hoare-style reasoning (`{P} op {Q}`):** each mutation contract can be translated directly.
- **State-machine modeling:** framework3 upgrades framework1 from pure topology grammar to topology + transition system.

Verdict: framework3 is valid and relevant as a domain-specific, contract-enriched variant.

---

## 6) Refined Final Framework3 (v1.0)

## Framework3 Specification

### Layer A — Structural Addressing (from framework1)
1. Keep framework1 sibling-recursive IDs as canonical logical addresses.
2. Normalize every target to `(grid, x, y)` runtime coordinate.
3. Preserve dot-qualified nesting semantics for deep operations.

### Layer B — State Invariants
1. Enforce coordinate and shape invariants (`I1`, `I3`).
2. Enforce ownership invariants (`I2`).
3. Enforce selection safety (`I4`).
4. Enforce undo-before-mutation (`I5`).
5. Enforce bounded creation and fold-visibility safety (`I6`, `I7`).

### Layer C — Behavioral Contracts
1. All mutators expose `PRE/TRANSFORM/POST/FAILSAFE` blocks.
2. Contracts are bound to `PathContext` to preserve framework1 traceability.
3. Contracts are categorized by operation family:
   - topology mutations,
   - content/style mutations,
   - navigation/selection mutations,
   - import/export transformations.

### Layer D — Verification Hooks
1. `check_invariants(grid/document)` after structural mutators in debug builds.
2. `contract_guard(op, context)` wrappers for script interface and UI commands.
3. `undo_scope_guard` to guarantee mutation capture via LCA.

### Layer E — Evolution Protocol
1. When adding a new primitive or command, define:
   - path binding,
   - invariants touched,
   - contract template.
2. Reject additions without explicit invariant/contract declaration.

---

## 7) Key Improvements vs Framework1

1. **From “where” to “where + whether + how”**
   - Framework1: addressing only.
   - Framework3: addressing + validity + legal transitions.

2. **Runtime alignment with source reality**
   - Framework3 maps symbolic IDs to actual TreeSheets objects and constraints.

3. **Safer mutation model**
   - Undo and bounds/ownership checks become first-class contract requirements.

4. **Auditability**
   - PathContext preserves traceability back to framework1 IDs for debugging and scripts.

5. **Implementation readiness**
   - Directly translatable to assertions, guards, and test cases.

---

## 8) Hypothesis Test Result and Conclusion

## Hypothesis

> Framework3 can be built by systematically integrating raw TreeSheets source semantics into framework1, yielding a more robust primitives/invariants/contracts framework.

## Result

**Supported.**

Reason:
- framework1 structure is preserved as Layer A,
- raw source contributes concrete invariant and contract semantics in Layers B/C,
- resulting framework is coherent, implementable, and better aligned with actual TreeSheets behavior.

## Limitations

1. Some contracts remain implicit in legacy code style and need gradual codification.
2. No formal machine-checked proof yet.
3. Cross-fork divergences (TreeSheets vs trimsheets vs 3shits) may require profile-specific contract variants.

---

## 9) Broader Implications, Impact, and Next Steps

### 9.1 Implications for practice

- Promotes safer refactoring in a dense codebase.
- Makes scripting/extensions less error-prone by exposing contract boundaries.
- Enables shared vocabulary across core devs and fork maintainers.

### 9.2 Productivity / efficiency / effectiveness impact

- **Productivity:** faster onboarding via explicit primitives + rules.
- **Efficiency:** fewer regression cycles through invariant-first debugging.
- **Effectiveness:** clearer correctness expectations for each edit operation.

### 9.3 Actionable implementation plan

1. Add `framework3` document to repo governance/docs.
2. Introduce debug-only invariant checker for `Grid`, `Selection`, `Document`.
3. Wrap script mutators with shared contract guards.
4. Add mutation tests covering:
   - insert/delete edge bounds,
   - merge/reparent safety,
   - folded-path navigation behavior,
   - undo LCA correctness.
5. Add CI job for contract/invariant test suite.

### 9.4 Future research / development

1. Formalize contracts in a lightweight DSL for auto-generated checks.
2. Add property-based tests for random grid mutations.
3. Define fork compatibility matrix (TreeSheets/trimsheets/3shits) with deltas per contract.
4. Explore optional persistent IDs beyond positional IDs for long-lived references.

---

## Appendix A — Quick Contract Templates

```text
CONTRACT mutate_X(context, args):
  PRE:
    resolve(context.logical_id) -> (grid,x,y)
    require invariants(I1..I7 subset)
  TRANSFORM:
    apply operation
  POST:
    require invariants(I1..I7 subset)
    require undo_scope_captured
    require selection_visibility_consistent
  FAILSAFE:
    no partial mutation on precondition failure
```

This appendix can be copied directly into implementation tickets.
