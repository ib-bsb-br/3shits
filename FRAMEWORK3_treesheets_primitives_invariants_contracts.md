# Framework3: TreeSheets Primitives, Invariants, and Behavioral Contracts

## A. Objective and Continuity with Framework1

This document defines **framework3** as an enhancement of **framework1**, preserving framework1's sibling-recursive addressing while adding two missing dimensions from TreeSheets source behavior:

1. **State invariants** (what must always be true).
2. **Behavioral contracts** (what each mutation must guarantee).

In compact form:

```text
framework3 = framework1_addressing + runtime_invariants + operation_contracts
```

Framework1 remains the address grammar backbone; framework3 adds formal runtime semantics.

---

## B. Step 1 — Framework1 Analysis (Core Principles)

From the provided framework1 notation and tree sketch:

- Addressing is **sibling-relative** (`sibling_OF`), not only absolute.
- Addressing is **recursive/compositional** (`(C01L#n).(C01L_)`).
- Indices encode predecessor/current/successor transitions (`n-01`, `n`, `01+n`).
- Dot-qualified IDs model hierarchical expansion (e.g., `C01L01.C01L___01`).

### Extracted framework1 strengths

- Strong symbolic locality and navigation.
- Reusable rule pattern across levels.

### Extracted framework1 gap

- No explicit legality model for runtime state or mutation safety.

---

## C. Step 2 — Raw Data Analysis (TreeSheets/3shits Source)

The raw data is the complete codebase; the following are the relevant operational anchors.

## C1. Primitives in code

- **Cell**: parent pointer, text, optional child grid, style/render state.
- **Grid**: owner cell, rectangular cell storage (`xs`, `ys`, `cells`), per-column widths.
- **Selection**: grid-scoped rectangle plus text-edit cursor state.
- **Document**: root, selection/hover, undo/redo history, draw path.

## C2. Invariant evidence in code behavior

- Bounds-checked cell dereference (`Grid::C`).
- Parent consistency updates during insert/merge/reparent.
- Grid shape discipline in insertion/deletion.
- Selection range confinement and nulling when invalid.
- Undo-before-mutation pattern in editing/mutating operations.
- Script guardrails for creation bounds and index checks.

## C3. Contract evidence in code behavior

Across structural/content operations, methods consistently imply:

- **Preconditions** (grid exists, indices valid, mutation allowed).
- **Transform** (mutate cell/grid/document state).
- **Postconditions** (layout/reset/refresh and navigational consistency).
- **Failsafe/no-op** branch when preconditions fail.

---

## D. Step 3 — Integration Strategy

## D1. Three-layer integration model

- **Layer A (Framework1 Addressing):** symbolic ID and sibling recursion.
- **Layer B (State Invariants):** legal-state constraints over runtime objects.
- **Layer C (Behavioral Contracts):** legal transition constraints over mutations.

## D2. Mapping framework1 to runtime

| Framework1 construct | Runtime correlate | Framework3 interpretation |
|---|---|---|
| `id(C..L..)` | resolved `(grid,x,y)` + `Cell*` | symbolic + concrete target identity |
| sibling rules | neighbor traversal in grid coordinates | explicit adjacency constraints |
| recursive dotted IDs | nested `Cell -> Grid -> Cell` ownership chain | hierarchical path resolution |
| index transforms | insert/delete/move mutation APIs | transition contracts |

---

## E. Step 4 — Draft Framework3 (v0.9)

## E1. Formal model

```text
Cell C := { parent: Cell?, text, grid: Grid?, style }
Grid G := { cell: Cell, xs>0, ys>0, cells[xs*ys], colwidths[xs], folded }
Selection S := { grid: Grid?, x,y,xs,ys, textedit, cursor,cursorend }
Document D := { root: Cell, selected, hover, undolist, redolist, drawpath }
```

## E2. Framework1-compatible path context

```text
PathContext := {
  logical_id,           // framework1-compatible symbolic address
  resolved_grid,        // runtime grid pointer
  resolved_coord(x,y),  // runtime coordinate
  depth,
  sibling_index
}
```

## E3. Global invariants

- **I1 Coordinate Safety:** valid bounds before dereference.
- **I2 Ownership Consistency:** each cell in a grid has parent == grid owner cell.
- **I3 Shape Consistency:** `len(cells)=xs*ys`, `len(colwidths)=xs`.
- **I4 Selection Validity:** non-null selection remains in-bounds.
- **I5 Undo Discipline:** user-visible mutation captures undo at suitable scope.
- **I6 Visibility Safety:** folded ancestry resolved before interaction path use.
- **I7 Construction Bounds:** new grid creation respects max-size guardrail.

## E4. Behavioral contracts (core operations)

### C1 CreateGrid(x,y)
- PRE: `x>0`, `y>0`, size below bound.
- TRANSFORM: attach grid to target cell.
- POST: invariants I1-I3,I7 hold; undo captured.
- FAILSAFE: no mutation on failed preconditions.

### C2 InsertColumn/InsertRow
- PRE: target grid exists, index in legal insertion range.
- TRANSFORM: reshape one axis by +1 and initialize inserted cells.
- POST: I1-I3 preserved; orientation/layout consistency preserved.
- FAILSAFE: no-op on invalid target/index.

### C3 DeleteRegion(x,y,xs,ys)
- PRE: region fully in bounds.
- TRANSFORM: clear/delete/collapse according to content and extent.
- POST: selection/view reconciled; root safety respected.
- FAILSAFE: aborts destructive action when illegal.

### C4 MoveSelection(dx,dy)
- PRE: grid-scoped non-text move mode.
- TRANSFORM: cyclic or bounded movement per selection semantics.
- POST: selection normalized or nullified if invalid.
- FAILSAFE: no memory/ownership break.

### C5 Content/Style mutation
- PRE: editable target exists.
- TRANSFORM: update text/note/style/color/image fields.
- POST: reset/refresh/update as required; undo preserved.
- FAILSAFE: reject invalid target state.

### C6 MergeWithParent
- PRE: parent and child grids exist.
- TRANSFORM: promote child cells into parent with conflict-aware expansion.
- POST: reparenting complete, ownership coherent, selection adjusted.
- FAILSAFE: no double ownership or double free.

---

## F. Step 5 — Evaluation of Draft Framework3

## F1. Coherence

The semantic chain is explicit and closed:

```text
framework1 symbolic path -> PathContext resolution -> invariant check -> contracted mutation -> invariant re-check
```

## F2. Completeness

Covers primitives, persistent invariants, and primary mutation categories (topology/content/navigation). It intentionally does not claim distributed concurrency semantics.

## F3. Clarity

Each operation now has PRE/TRANSFORM/POST/FAILSAFE semantics, reducing ambiguity compared with framework1-only addressing.

## F4. Practicality

Can be applied incrementally through debug assertions, guard wrappers, and targeted tests.

## F5. Comparison to established approaches

- **Design by Contract:** framework3 is DbC-compatible by design.
- **Hoare logic style:** each operation maps to `{P} op {Q}`.
- **Hierarchical model checking:** framework3 can be tested per subtree/path context.

Conclusion: draft is valid and operationally relevant.

---

## G. Step 6 — Refined Framework3 (v1.0)

## G1. Final specification layers

1. **Address Layer:** retain framework1 IDs and recursion.
2. **Resolution Layer:** map symbolic IDs to runtime `(grid,x,y)` targets.
3. **Invariant Layer:** enforce I1-I7 globally.
4. **Contract Layer:** enforce C1-C6 on all mutators.
5. **Verification Layer:** run pre/post invariant checks and guard logs.
6. **Evolution Layer:** require every new mutator to declare touched invariants/contracts.

## G2. Standard contract template

```text
CONTRACT op(context,args):
  PRE: resolve(context.logical_id); require relevant invariants
  TRANSFORM: apply mutation
  POST: require relevant invariants; require undo discipline
  FAILSAFE: no partial mutation if PRE fails
```

---

## H. Step 7 — Key Improvements Over Framework1

1. Adds legality semantics to symbolic addressing.
2. Makes mutation safety and undo discipline explicit.
3. Provides traceability from framework1 IDs to runtime targets.
4. Supports systematic testing and safer refactoring.
5. Bridges UI actions and script API under one contract vocabulary.

---

## I. Step 8 — Hypothesis Test and Conclusion

### Hypothesis

Framework3 can be constructed by integrating TreeSheets raw-data semantics into framework1 while preserving framework1 identity.

### Result

**Supported.**

Framework1 is preserved as the addressing layer; raw data contributes concrete invariants and contracts; the integrated system is more robust and actionable.

### Limitations

- Legacy code may encode some contracts implicitly rather than explicitly.
- No formal theorem-proof layer is provided here.
- Forks may need profile-specific contract deltas.

---

## J. Step 9 — Broader Implications and Next Steps

## J1. Practical impact

- **Productivity:** clearer mental model for contributors.
- **Efficiency:** fewer regressions via invariant-guided debugging.
- **Effectiveness:** safer scripting and mutation behavior.

## J2. Implementation next steps

1. Add shared invariant-check utility for `Grid`, `Selection`, `Document` in debug builds.
2. Add contract guards around mutators in script interface and UI command paths.
3. Add mutation-focused tests for bounds, reparenting, fold visibility, and undo scope.
4. Add CI stage for contract/invariant checks.

## J3. Further research

1. Lightweight DSL for declaring contracts and generating checks.
2. Property-based mutation testing over random grid operations.
3. Fork compatibility matrix (TreeSheets / trimsheets / 3shits).
4. Optional persistent IDs to complement positional framework1 paths.

---

## K. Deliverable Summary

Framework3 is now a **path-aware, invariant-governed, contract-driven** extension of framework1, directly grounded in TreeSheets runtime primitives and mutation behavior. It preserves framework1 identity and adds the missing dimensions needed for correctness, maintainability, and implementable engineering practice.
