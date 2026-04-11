# Sibling Cells vs Neighbor Cells in TreeSheets

## Purpose

This essay contrasts **SIBLING** and **NEIGHBOR** cells in TreeSheets using three coupled lenses:

1. **Symbolic** (address grammar / path meaning),
2. **Semantic** (what relation means),
3. **Structural** (what pointers and containers enforce).

It is grounded in framework3: path-aware, invariant-governed, contract-driven reasoning.

---

## 1) Core thesis

A concise distinction:

- **Sibling** = relation of **origin** and **co-membership under the same parent-owned grid**.
- **Neighbor** = relation of **proximity** in a given layout or coordinate frame.

Every sibling can be spatially near or far depending on layout and folding context; every neighbor can belong to the same parent or not depending on view, zoom root, and projection.

So:

```text
Sibling is genealogical/topological.
Neighbor is geometric/contextual.
```

---

## 2) Minimal formalization

Let:

- `parent(c)` be the parent cell pointer of cell `c`.
- `owner_grid(c)` be the grid that stores `c` as an element.
- `coord(c) = (x,y)` within `owner_grid(c)`.
- `dist(c1,c2)` be spatial distance in the active view context.

Define:

```text
Sibling(c1,c2) := parent(c1) == parent(c2)
                  AND owner_grid(c1) == owner_grid(c2)
                  AND c1 != c2

Neighbor(c1,c2 | context) := dist(c1,c2) <= epsilon(context)
                             OR c2 belongs to local adjacency(c1, context)
```

Notice the asymmetry:

- `Sibling` is parent/owner invariant and does not depend on camera/view context.
- `Neighbor` depends on chosen context (grid coordinates, rendered pixels, folded visibility, draw root, etc.).

---

## 3) Symbolic contrast (address language)

## 3.1 Sibling in symbolic grammar

In framework1/framework3 address language, siblings are naturally represented by shared prefix path and differing terminal segment:

- `P.parent.child_01`
- `P.parent.child_02`

Same `P.parent` origin; distinct child slot.

Symbolically this is a **beginning-first** relation:

- first ask: “From which parent branch do they come?”
- then ask: “Which specific child slot are they?”

## 3.2 Neighbor in symbolic grammar

Neighbor is usually encoded as an operator over already-resolved location:

- `at(P).adjacent(+1,0)`
- `at(P).adjacent(0,+1)`

This is a **location-first** relation:

- first ask: “Where am I now?”
- then ask: “Which cells are around this location in the active adjacency model?”

## 3.3 Beginning versus location

- Sibling addresses start from **beginning/origin** (same branch ancestry).
- Neighbor addresses start from **location/proximity** (what lies around this point).

---

## 4) Semantic contrast (meaning)

## 4.1 Origin vs proximity

- **Sibling** means shared derivation, like same family line.
- **Neighbor** means local closeness, like same block.

## 4.2 Inheritance vs coexistence

- Siblings inherit from common parent constraints (style defaults, structural membership, lifecycle implications).
- Neighbors merely coexist near each other; they need not share parent, type, or lifecycle.

## 4.3 Inevitability vs contingency

- Siblinghood is **inevitable** once parent ownership is established.
- Neighborhood is **contingent** on representation choices:
  - folded/unfolded states,
  - zoom path,
  - rendering projection,
  - adjacency metric.

## 4.4 Memory vs boundary

- Sibling relation is memory-bearing: it encodes historical/topological origin.
- Neighbor relation is boundary-bearing: it encodes immediate frontier around a location.

## 4.5 Fusion vs adjacency

- Siblings are fused into a common ownership domain.
- Neighbors are adjacent in space but not fused in ownership.

## 4.6 Internal vs external relation

- Sibling is internal to a parent-owned structure.
- Neighbor is externalized by viewpoint and local geometry.

---

## 5) Structural contrast in TreeSheets terms

## 5.1 Sibling is pointer-topology truth

Siblinghood is stabilized by these structural facts:

- same parent pointer,
- same containing grid,
- different slot indices in that grid.

When structural operations occur (insert/delete/merge/reparent), sibling sets change according to ownership changes, not according to pixel distance.

## 5.2 Neighbor is coordinate/view truth

Neighborhood is stabilized by context-specific adjacency:

- same grid and one-step coordinate difference (grid-neighbor), or
- spatial nearness in rendered view (visual-neighbor), or
- navigation-neighbor in selection movement rules.

Thus one cell can have multiple neighborhood definitions simultaneously, but only one sibling ancestry at a time.

---

## 6) Extensive dummy illustrations

## 6.1 Illustration A — House lineage vs street proximity

```text
GENEALOGY MODEL (siblings)
GrandHouse
└── ParentHouse
    ├── Room_A
    ├── Room_B
    └── Room_C

- Room_A and Room_B are siblings: same ParentHouse.
- Even if Room_A is physically far after renovation, siblinghood remains.

STREET MODEL (neighbors)
Street coordinates:
(0,0)=Shop_X, (1,0)=Room_A, (2,0)=Cafe_Y

- Room_A neighbor set may be {Shop_X, Cafe_Y}.
- Shop_X is a neighbor of Room_A but not a sibling.
```

## 6.2 Illustration B — "Die together" genealogy variant

```text
PARENT > children/siblings
Case 1: single child
- parent removed => child lineage anchor disappears with parent context.
- meaning-loss is total for that branch.

Case 2: many children
- one child removed => siblings survive; parent branch remains.
- removed child loses branch membership; parent meaning partially reduced but preserved.
```

Interpretation: sibling semantics attach to parent continuity, not local proximity.

## 6.3 Illustration C — "Die together" locator/tenant (neighbor) variant

```text
LOCADOR > locatarios/neighbors
Case 1: single tenant neighbor
- tenant disappears => locador loses immediate adjacency utility (income/interaction context) entirely.

Case 2: many tenant neighbors
- one tenant disappears => local resource decreases, but locador and other neighbors persist.
```

Interpretation: neighbor semantics attach to contingent local boundary/resources, not shared origin.

## 6.4 Illustration D — Same siblings, different neighbors under fold

```text
Topology (unchanged): Parent has children A,B,C (siblings always).
View state 1 (expanded): A visually near B and C.
View state 2 (folded/zoomed): only A visible; B/C not currently visual neighbors.

Result:
- Sibling(A,B) remains true in both states.
- Neighbor(A,B | visual-context) may flip true -> false.
```

## 6.5 Illustration E — Same neighbor, different ancestry

```text
Grid G1: contains cell P.child_01
Grid G2: contains cell Q.child_09
Rendered side-by-side in a dashboard.

If projected close, they are visual neighbors.
But they are not siblings because parent lineage differs (P != Q).
```

---

## 7) Contrast matrix (quick reference)

| Dimension | Sibling | Neighbor |
|---|---|---|
| Primitive question | “Who is your parent?” | “Who is close to you?” |
| Anchor | Origin / ancestry | Location / boundary |
| Stability | High (topology-stable) | Medium/low (context-stable) |
| Depends on fold/zoom/view | No | Yes (often) |
| Relation type | Internal ownership relation | External proximity relation |
| Typical operation impact | Insert/delete/reparent changes sibling sets | Layout/projection/nav changes neighbor sets |
| Memory content | Historical branch membership | Current frontier composition |
| Contingency | Low | High |

---

## 8) Practical contracts to avoid confusion

To keep framework3 implementations robust, explicitly separate contracts:

## 8.1 Sibling contract

```text
SIBLING_PRE(c1,c2):
  require parent(c1) != null
  require parent(c2) != null

SIBLING_CHECK(c1,c2):
  return parent(c1) == parent(c2)
      && owner_grid(c1) == owner_grid(c2)
      && c1 != c2
```

## 8.2 Neighbor contract

```text
NEIGHBOR_PRE(c1,c2,context):
  require context.adjacency_model is defined
  require both cells are resolvable in context

NEIGHBOR_CHECK(c1,c2,context):
  return AdjacentUnderModel(c1,c2,context)
```

## 8.3 Anti-confusion rule

Never infer siblinghood from neighborhood, and never infer neighborhood from siblinghood, unless a specific theorem is declared for the exact context.

---

## 9) How this plugs into framework3

In framework3 layers:

1. **Address Layer** resolves symbolic identities.
2. **Resolution Layer** binds runtime targets.
3. **Invariant Layer** ensures ownership and shape validity.
4. **Contract Layer** must separate `Sibling(...)` predicates from `Neighbor(...|context)` predicates.
5. **Verification Layer** tests both independently.

This prevents category errors such as:

- treating spatial adjacency as lineage,
- treating shared parentage as guaranteed visual proximity.

---

## 10) Final conceptual distillation

Sibling and neighbor are not rival words for the same relation; they are orthogonal coordinates in TreeSheets reasoning.

- **Sibling** answers: “Where do you come from?”
- **Neighbor** answers: “Who surrounds you now?”

In framework3 terms:

- sibling belongs to **structural truth**,
- neighbor belongs to **contextual truth**.

Robust systems preserve both truths without collapsing one into the other.
