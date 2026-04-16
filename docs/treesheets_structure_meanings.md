# TreeSheets structure meanings: explicit semantics and inferable semantics

This document answers a specific question: what meanings are **actually encoded** by TreeSheets data structures and operations, even though TreeSheets is intentionally a generic organizer and does not enforce domain-specific ontology.

## 1) What the core data model explicitly means

## 1.1 Cell as the fundamental semantic unit
- A `Cell` can contain:
  - scalar-like content (`Text`),
  - structured content (`Grid *grid`),
  - a pointer to its immediate parent (`Cell *parent`),
  - presentation and typing markers (`celltype`, draw style, colors).
- This means TreeSheets encodes **content + containment + local role marker** at each node.

## 1.2 Grid as ordered sibling space
- A `Grid` stores children as `Cell **cells` with dimensions `xs`, `ys`.
- Access is done through `C(x,y)` indexing over `cells[x + y * xs]`.
- So sibling relation is not only "same parent" but also **coordinate-indexed siblinghood**.

## 1.3 Parent-child relation is strict tree containment
- Child cells keep back-reference to owner cell through `parent`.
- Many operations explicitly repair this relation (`ReParent`, `SetParent`, cloning paths), meaning the parent-child edge is a first-class invariant.

## 1.4 Cell type tags provide program-level meaning
- `CT_DATA`: plain data.
- `CT_CODE`: operation/function token.
- `CT_VARD`: variable assignment.
- `CT_VARU`: variable read.
- `CT_VIEWH` / `CT_VIEWV`: orientation-dependent view extraction.
- These are not domain semantics (e.g., "customer", "task"), but they are **computational semantics**.

## 2) Meanings directly inferable from structural invariants

## 2.1 Ordered tree + ordered matrix hybrid
TreeSheets is not just a tree and not just a table. It is a recursively nested matrix where every matrix element can itself be another matrix. This yields:
- vertical/horizontal neighborhood meaning,
- ancestor/descendant meaning,
- path meaning (root→...→leaf),
- level meaning (depth).

## 2.2 Coordinates encode role even without labels
Because child position is stable (`x`,`y`), a parent can imply schemas such as:
- column `x=0` as key/name dimension,
- row `y=0` as header/category dimension,
- `(x,y)` as cross-product attribute slot.

This is inferable semantics, not enforced semantics.

## 2.3 Siblinghood supports equivalence classes
Children under the same parent grid are natural candidates for:
- alternatives,
- ordered sequence elements,
- grouped peer facts.

Whether they are peers "in meaning" depends on user convention, but structure supports that reading.

## 3) Meanings introduced by grid reorganization operations

## 3.1 Transpose
Explicit effect:
- `Transpose` remaps `tr[y + x * ys] = c`, swaps `xs`/`ys`, and re-initializes orientation metadata.

Meaning effects:
- Turns row semantics into column semantics (and vice versa).
- Swaps which sibling axis encodes primary grouping.
- Preserves containment while rotating coordinate meaning.

## 3.2 Hierarchify
Explicit effect:
- For repeated first-column values, merges rows into hierarchical subgrids (`MergeRow`) under the repeated key cell.
- Deletes redundant columns/rows after promoting hierarchy.
- Recurses into nested grids.

Meaning effects:
- Converts tabular redundancy into parent-child factorization.
- Interprets repeated key values as the same entity node.
- Rewrites from "record-per-row" meaning to "entity with nested attributes/records" meaning.

## 3.3 Flatten
Explicit effect:
- Traverses hierarchy depth-first.
- For each leaf, writes ancestor chain text into a flat output grid by depth index.

Meaning effects:
- Converts implicit path semantics into explicit columns.
- Materializes ancestor context for each leaf as a relational-like row.
- Replaces nested containment meaning with denormalized path tuples.

## 3.4 Hierarchy Swap
Explicit effect:
- Finds tagged node text in descendants.
- Builds reverse hierarchy by wrapping found nodes with prior parent tags.
- Deletes obsolete parent chain fragments and merges equal tags.

Meaning effects:
- Re-anchors perspective around a chosen tag/key.
- Performs semantic pivoting of "who is parent of whom" for matching subtrees.
- Can merge nodes that become siblings under the new root criterion.

## 3.5 MergeWithParent / wrapping / structural edits
- `MergeWithParent` can splice child-grid cells into parent coordinates, including insertion conflict handling.
- "Wrap in new parent" creates a new super-node around selection.

Meaning effects:
- changes abstraction boundary,
- changes which facts are contextual metadata vs peer facts,
- can reinterpret previous siblings as descendants (or inverse).

## 4) Meanings in evaluation/program structures

## 4.1 Grid as executable expression space
`Grid::Eval` scans rows and columns with accumulator semantics, treating cell types as operators/operands/stateful actions.

Inferable meaning:
- Local left-to-right and top-to-bottom order are computational orderings.
- Layout can double as program structure.

## 4.2 Algebraic and comparison semantics
Built-in operations include:
- arithmetic: `+ - * / inc dec neg`,
- comparison: `< > <= >= = == != <>`,
- aggregate/list: `sum`,
- structure transform: `transpose`,
- conditional (ternary): `if`,
- graph/text-oriented op: `graph`.

Meaning effects:
- Cells can denote formulas, transformations, and predicates.
- Numeric and boolean interpretations are projected from text when operation requires it.

## 4.3 Variable semantics and destructuring
- `CT_VARD` assigns symbol -> value.
- `CT_VARU` reads symbol.
- Destructuring assignment maps grid-shaped symbol patterns to grid-shaped values when dimensions match.

Meaning effects:
- Structural shape itself becomes part of variable binding semantics.
- A grid can represent tuples/records for assignment without explicit type declarations.

## 4.4 View semantics
`CT_VIEWH`/`CT_VIEWV` act as orientation-dependent view selectors/markers during evaluation.

Meaning effects:
- Same structure can expose alternate interpretations by traversal direction.
- Adds perspectival meaning without changing stored raw data.

## 5) Export/import and representational meaning

## 5.1 CSV export constraint encodes “flatness requirement”
UI/tooling states CSV export only for non-nested grids (or after flatten).

Meaning inference:
- TreeSheets distinguishes between hierarchical meaning and flat tabular meaning; conversion is explicit.

## 5.2 XML/HTML/text export preserves nested structure
`ToText`/`ConvertToText` emit rows/cells and nested grids recursively, so structure is serializable as meaning-bearing syntax.

## 6) Catalog of possible meanings users can infer from TreeSheets structures

Given the generic model, users can map structures into many semantic regimes:

- Ontological: class→instance, type→attribute, taxonomy.
- Mereological: whole→part decomposition.
- Temporal: period→event→subevent.
- Procedural: process→step→substep.
- Argumentative: claim→premise→evidence.
- Computational: expression trees, dataflow blocks, variable scopes.
- Relational emulation: table rows/columns, then hierarchified dimensions.
- Graph projection: node descriptors in cells, with parent/child as spanning tree over an implicit graph.
- Knowledge organization: topic→subtopic→note.
- Requirements engineering: feature→requirement→test case.
- Project management: project→work package→task.

All of these are possible because TreeSheets commits only to generic structural semantics: containment, ordering, coordinates, and optional executable typing.

## 7) Limits: meanings TreeSheets does NOT intrinsically encode

From code and UI model, TreeSheets does not intrinsically enforce:
- domain ontologies,
- type systems with schema validation,
- referential integrity across arbitrary nodes,
- cardinality constraints,
- semantic role labels beyond user text and generic cell type tags.

So meaning is partly explicit (structure + operations), partly conventional (user interpretation), exactly as Wouter described.

## 8) Practical synthesis

TreeSheets provides:
1. **Explicit machine semantics** (tree/grid geometry + operation cell types + evaluator operations).
2. **Transformational semantics** (Transpose/Hierarchify/Flatten/Hierarchy Swap) that reinterpret structure.
3. **Open-ended inferential semantics** supplied by user modeling conventions.

Hence, "generic" in TreeSheets does not mean "meaningless"; it means **meaning is structural/computational rather than domain-hardcoded**.

## 9) Source grounding map (where each semantic claim comes from)

- Core node typing and parent/grid ownership: `src/cell.h` (`Cell`, `celltype`, `parent`, `grid`, `Eval`).
- Coordinate sibling model and matrix indexing: `src/grid.h` (`xs`, `ys`, `cells`, `C(x,y)`, iteration macros).
- Reorganization operations: `src/grid.h` (`Transpose`, `HierarchySwap`, `Hierarchify`, `Flatten`, `MergeWithParent`, `ReParent`).
- Program/evaluator semantics and algebraic ops: `src/evaluator.h` (`Operation`, `Evaluator::Init`, `Execute`, variable assignment/lookup).
- UI semantic descriptions for operations (human-facing wording): `src/tsframe.h` (menu strings for Transpose, Hierarchify, Flatten, Hierarchy Swap, operation reference).
