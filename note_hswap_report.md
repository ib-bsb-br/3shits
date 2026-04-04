<purpose>
  Produce a structured, sanitized report that enumerates the note primitive data
  structure and its operational relationships with Hierarchy Swap (A_HSWAP)
  behavior for the TreeSheets codebase, using local sources plus attached
  commit metadata as evidence.
</purpose>

<context>
  <role>
    Documentation Analyst / Technical Revisor.
    <tone>Formal, coherent, impersonal, and extensive.</tone>
    <domain>Content Management.</domain>
  </role>

  <input_handling>
      Treat attachment files as the embedded commit diff excerpts supplied in the
      request, and treat the user request as the authoritative statement of the
      scope and required focus.
  </input_handling>

  <constraints>
    <constraint type="critical">TOTAL SANITIZATION: Replace all template facts with
    new, source-based content about the note data structure and A_HSWAP behavior.</constraint>
    <constraint type="critical">INFERENCE ALLOWED: When details are implied by code
    structure (e.g., field ownership or lifecycle), infer plausible operational
    consequences.</constraint>
    <constraint type="critical">CONFLICT RESOLUTION: If raw data and attachment
    metadata diverge, record both values with source attribution.</constraint>
    <constraint type="formatting">PRESERVE STRUCTURE: Keep section order, list
    styling, and indentation aligned with the provided skeleton.</constraint>
  </constraints>
</context>

<instructions>
  <instruction step="1">STRUCTURAL MAPPING: Identify fixed headings, lists, and
  placeholders in the skeleton and reapply them for the note/A_HSWAP narrative.</instruction>

  <instruction step="2">DATA EXTRACTION:
    a. Parse the local repository for the note field, its serialization,
       rendering cues, scripting bindings, and UI surfaces.
    b. Parse the attachment commit diffs for the timeline of note-related
       changes and record them as external corroboration.</instruction>

  <instruction step="3">CONFLICT CHECK: Compare user-supplied scope and attachment
  metadata. If the attachment set includes unrelated entries, note them without
  contaminating the note/A_HSWAP focus.</instruction>

  <instruction step="4">DRAFTING & SUBSTITUTION:
    a. Rebuild the document layout as-is.
    b. Replace identifiers with the current repository and feature context.
    c. Restate operational behavior in clear, impersonal prose.
    d. Ensure A_HSWAP interactions are explained even when indirect.</instruction>

  <instruction step="5">LIST HANDLING:
    a. Preserve list style in every section.
    b. Include all note-related touchpoints found in source and metadata.
    c. Omit placeholder items that are not supported by the new data.</instruction>

  <instruction step="6">GAP FILLING: When a field lacks explicit data, infer a
  reasonable completion (e.g., missing ownership details).</instruction>

  <instruction step="7">DISCREPANCY REPORTING: Add or populate an OBSERVATIONS
  section to highlight scope gaps, unrelated attachment items, or conflicts.</instruction>

  <instruction step="8">ANTI-RESIDUE SCAN: Verify that all template-specific facts
  are removed and replaced with note/A_HSWAP content.</instruction>
</instructions>

<examples>
  <example>
    <scenario>Cell-Level Note Storage</scenario>
    <input_fragment_template><![CDATA[
      FIELD: <placeholder>
      STATUS: <placeholder>
      LOCAL: <placeholder>
    ]]></input_fragment_template>
    <input_fragment_new_data><![CDATA[
      The note is stored on each cell as a dedicated string field and persists
      through serialization.
    ]]></input_fragment_new_data>
    <output_fragment><![CDATA[
      FIELD: Cell.note (string)
      STATUS: Persisted via save/load routines
      LOCAL: Core cell structure and serialization paths
    ]]></output_fragment>
  </example>

  <example>
    <scenario>Hierarchy Swap Interaction</scenario>
    <input_fragment_template><![CDATA[
      ACTION: <placeholder>
      EFFECT: <placeholder>
    ]]></input_fragment_template>
    <input_fragment_new_data><![CDATA[
      A_HSWAP promotes cells based on text matching and reorganizes parent chains;
      note is not used as a matching key.
    ]]></input_fragment_new_data>
    <output_fragment><![CDATA[
      ACTION: A_HSWAP (Hierarchy Swap)
      EFFECT: Note remains attached to moved cells but does not influence match
    ]]></output_fragment>
  </example>
</examples>

<input_data>
  <template_document><![CDATA[
    [[
      <record>
        <title>Note Primitive and A_HSWAP Interaction Report</title>
        <scope>
          Extract and enumerate every note-related feature, persistence path,
          script binding, and UI surface, plus its direct or indirect influence
          on Hierarchy Swap execution.
        </scope>
        <entities>
          <entity>
            <name>Cell.note</name>
            <type>string</type>
            <ownership>Per-cell field within the core cell structure.</ownership>
          </entity>
          <entity>
            <name>A_HSWAP / Hierarchy Swap</name>
            <type>action identifier and structural transformation routine</type>
            <ownership>Menu action mapped to Document::Action and Grid::HierarchySwap.</ownership>
          </entity>
        </entities>
        <note_surface_map>
          <item>Core field stored on Cell as a wxString and initialized empty.</item>
          <item>Rendered as a corner indicator triangle when the note is non-empty and the cell is not tiny or the draw root.</item>
          <item>Triangle color is derived from the cell text color via lightened rendering, ensuring visibility alongside text.</item>
          <item>Serialized to the document stream and restored on load for compatible versioned files.</item>
          <item>Copied through cloning and paste paths, with explicit exceptions for automatic style inheritance.</item>
          <item>Updated through the note dialog and script bindings.</item>
          <item>Queryable and filterable through actions and script APIs.</item>
        </note_surface_map>
        <procedure_map>
          <item>A_EDITNOTE opens a modal dialog for note editing, reuses the last dialog size, and focuses the note text field.</item>
          <item>A_EDITNOTE commits changes only when the note content differs, then persists dialog size values.</item>
          <item>A_FILTERNOTE flags text filtering using note emptiness and refreshes layout.</item>
          <item>Script API exposes get_note/set_note for automation.</item>
        </procedure_map>
        <hierarchy_swap_interaction>
          <summary>
            The swap routine matches cells by text only; note is not a selector
            but moves with the cell instance as it is promoted or merged.
          </summary>
          <details>
            <item>Matching uses exact text; note does not affect the match key.</item>
            <item>Cells promoted by the swap carry their note field with them, because the note is stored on the Cell itself.</item>
            <item>Ancestor clones created during swap are created via cloning but do not inherit notes when style cloning is used for automatic inheritance.</item>
            <item>Explicit style transfer can copy notes to selected cells via grid style application.</item>
            <item>Filtering by note can change visibility before invoking the swap, but does not alter the underlying swap logic.</item>
          </details>
        </hierarchy_swap_interaction>
        <commit_timeline>
          <item>Jan 31, 2026: Add Note functionality (adds Cell.note, render indicator, save/load, edit dialog, and menu entry).</item>
          <item>Jan 31, 2026: Support dark mode (note indicator uses dark/light brushes before later colorization).</item>
          <item>Jan 31, 2026: Colorize the note indicator triangle using the text color for visibility.</item>
          <item>Jan 31, 2026: Provide scripting functions for note access (interface, implementation, and script reference).</item>
          <item>Jan 31, 2026: Add filter action for cells with notes and wire it into the filter menu.</item>
          <item>Jan 31, 2026: Assign CTRL+E to Edit Note in the menu.</item>
          <item>Jan 31, 2026: Set focus on the note text field in the dialog.</item>
          <item>Jan 31, 2026: Remove unused parameter in the note dialog close handler.</item>
          <item>Feb 1, 2026: Remember note dialog size across sessions and write config values on shutdown.</item>
          <item>Feb 1, 2026: Only write note when it changes to avoid redundant undo and refresh.</item>
          <item>Feb 2, 2026: Do not inherit note when cloning cell styles, but allow explicit style pasting to include notes.</item>
        </commit_timeline>
        <evidence_register>
          <item>Local code shows note stored in Cell, saved/loaded, rendered, and copied during clone/paste paths.</item>
          <item>Local action handler shows A_EDITNOTE workflow, A_FILTERNOTE filtering, and A_HSWAP validation and call flow.</item>
          <item>Local hierarchy swap implementation shows text-only matching and ancestor cloning behavior.</item>
          <item>Attachment commit diffs enumerate note-related changes in late Jan and early Feb 2026, including UI, scripting, and cloning adjustments.</item>
        </evidence_register>
        <observations>
          <item>The attachment set includes a "Support dark mode" change that touches note indicator rendering; it is adjacent to note work but not a new note feature.</item>
          <item>No direct conflicts were identified between raw scope and the attachment diffs; the attachment data expands on note lifecycle and UI behavior rather than contradicting it.</item>
        </observations>
      </record>
    ]]
  ]]></template_document>

  <new_raw_data><![CDATA[
    [[User request: extract all aspects of the note primitive data structure
    and its interactions with Hierarchy Swap (A_HSWAP) procedures, referencing
    the TreeSheets repository and the specified commit window.]]
  ]]></new_raw_data>

  <attachment_files><![CDATA[
    [[Attachment A: commit diffs for note-related changes from late Jan through early Feb 2026, including Cell.note storage, rendering, dialog updates, filtering, scripting API, and cloning/paste semantics.]]
  ]]></attachment_files>
</input_data>

<output_specification>
  <format>Plain text or Markdown, strictly mirroring the layout of the template.</format>
  <language>en_US</language>
</output_specification>
