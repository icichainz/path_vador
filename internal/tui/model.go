package tui

import (
	"fmt"
	"os"
	"runtime"
	"strings"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/icichainz/path_vador/pkg/pathvador"
)

type operationID string

const (
	opJoin      operationID = "join"
	opClean     operationID = "clean"
	opAbs       operationID = "abs"
	opBase      operationID = "base"
	opDir       operationID = "dir"
	opEnvExport operationID = "env-export"
	opEnvUnset  operationID = "env-unset"
)

type fieldDefinition struct {
	Label        string
	InitialValue string
	Placeholder  string
	Hint         string
}

type operation struct {
	ID          operationID
	Title       string
	Description string
	Fields      []fieldDefinition
}

type operationItem struct {
	operation operation
}

func (i operationItem) Title() string       { return i.operation.Title }
func (i operationItem) Description() string { return i.operation.Description }
func (i operationItem) FilterValue() string { return i.operation.Title + " " + i.operation.Description }

type previewState struct {
	Title string
	Body  string
	Note  string
	Error bool
}

type keyMap struct {
	Up    key.Binding
	Down  key.Binding
	Next  key.Binding
	Prev  key.Binding
	Reset key.Binding
	Quit  key.Binding
}

func (k keyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Up, k.Down, k.Next, k.Prev, k.Reset, k.Quit}
}

func (k keyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{{k.Up, k.Down, k.Next, k.Prev, k.Reset, k.Quit}}
}

type styles struct {
	App          lipgloss.Style
	Header       lipgloss.Style
	Title        lipgloss.Style
	Subtitle     lipgloss.Style
	Panel        lipgloss.Style
	PanelTitle   lipgloss.Style
	PanelBody    lipgloss.Style
	FieldLabel   lipgloss.Style
	FieldLabelOn lipgloss.Style
	FieldHint    lipgloss.Style
	Result       lipgloss.Style
	ResultErr    lipgloss.Style
	Note         lipgloss.Style
	Footer       lipgloss.Style
}

type Model struct {
	width       int
	height      int
	list        list.Model
	help        help.Model
	keys        keyMap
	operations  []operation
	inputs      []textinput.Model
	activeInput int
	values      map[operationID][]string
	preview     previewState
	styles      styles
}

func NewModel() *Model {
	ops := defaultOperations()
	items := make([]list.Item, 0, len(ops))
	for _, op := range ops {
		items = append(items, operationItem{operation: op})
	}

	delegate := list.NewDefaultDelegate()
	delegate.SetHeight(2)
	delegate.SetSpacing(1)
	delegate.Styles.NormalTitle = lipgloss.NewStyle().
		Foreground(colorMuted).
		Padding(0, 0, 0, 1)
	delegate.Styles.NormalDesc = lipgloss.NewStyle().
		Foreground(colorSubtle).
		Padding(0, 0, 0, 1)
	delegate.Styles.SelectedTitle = lipgloss.NewStyle().
		Foreground(colorAccentWarm).
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(colorAccentWarm).
		Bold(true).
		Padding(0, 0, 0, 1)
	delegate.Styles.SelectedDesc = lipgloss.NewStyle().
		Foreground(colorAccentCool).
		Padding(0, 0, 0, 1)

	opList := list.New(items, delegate, 28, 12)
	opList.Title = "Operations"
	opList.SetShowTitle(false)
	opList.SetShowHelp(false)
	opList.SetShowStatusBar(false)
	opList.SetShowPagination(false)
	opList.SetFilteringEnabled(false)
	// The inputs are always focused, so the list may only react to up/down;
	// its default letter shortcuts (j, k, q, g, ...) would swallow typing.
	opList.KeyMap = list.KeyMap{
		CursorUp:   key.NewBinding(key.WithKeys("up")),
		CursorDown: key.NewBinding(key.WithKeys("down")),
	}
	opList.DisableQuitKeybindings()

	helpView := help.New()
	helpView.Styles.ShortKey = lipgloss.NewStyle().Foreground(colorAccentCool)
	helpView.Styles.ShortDesc = lipgloss.NewStyle().Foreground(colorSubtle)
	helpView.Styles.ShortSeparator = lipgloss.NewStyle().Foreground(colorBorder)

	model := &Model{
		list:       opList,
		help:       helpView,
		keys:       defaultKeys(),
		operations: ops,
		values:     make(map[operationID][]string, len(ops)),
		styles:     defaultStyles(),
	}

	model.seedDefaultValues()
	model.syncInputs()
	model.refreshPreview()
	return model
}

func (m *Model) Init() tea.Cmd {
	return m.syncInputFocus()
}

func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.resize()
	}

	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch {
		case key.Matches(keyMsg, m.keys.Quit):
			return m, tea.Quit
		case key.Matches(keyMsg, m.keys.Next):
			m.nextInput()
			m.refreshPreview()
			return m, m.syncInputFocus()
		case key.Matches(keyMsg, m.keys.Prev):
			m.previousInput()
			m.refreshPreview()
			return m, m.syncInputFocus()
		case key.Matches(keyMsg, m.keys.Reset):
			m.clearCurrentOperation()
			m.refreshPreview()
			return m, m.syncInputFocus()
		}
	}

	previousOperation := m.selectedOperation().ID
	var listCmd tea.Cmd
	m.list, listCmd = m.list.Update(msg)

	if m.selectedOperation().ID != previousOperation {
		m.activeInput = 0
		m.syncInputs()
		m.refreshPreview()
		return m, tea.Batch(listCmd, m.syncInputFocus())
	}

	if len(m.inputs) > 0 {
		var inputCmd tea.Cmd
		m.inputs[m.activeInput], inputCmd = m.inputs[m.activeInput].Update(msg)
		m.storeInputValues()
		m.refreshPreview()
		return m, tea.Batch(listCmd, inputCmd)
	}

	return m, listCmd
}

func (m *Model) View() string {
	if m.width == 0 {
		return m.styles.App.Render("Launching path_vador…")
	}

	header := m.styles.Header.Render(lipgloss.JoinVertical(
		lipgloss.Left,
		m.styles.Title.Render("path_vador"),
		m.styles.Subtitle.Render("Bubble Tea workbench for path shaping and ephemeral shell commands"),
	))

	footer := m.styles.Footer.Width(max(20, m.width-4)).Render(m.help.View(m.keys))

	if m.width < 92 {
		sidebarWidth := max(24, m.width-4)
		mainWidth := sidebarWidth
		content := lipgloss.JoinVertical(
			lipgloss.Left,
			header,
			m.renderSidebar(sidebarWidth, 12),
			m.renderForm(mainWidth),
			m.renderPreview(mainWidth),
			footer,
		)
		return m.styles.App.Render(content)
	}

	sidebarWidth := clamp(m.width/3, 28, 34)
	mainWidth := max(36, m.width-sidebarWidth-7)
	bodyHeight := max(18, m.height-8)

	sidebar := m.renderSidebar(sidebarWidth, bodyHeight)
	mainPanel := lipgloss.JoinVertical(
		lipgloss.Left,
		m.renderForm(mainWidth),
		m.renderPreview(mainWidth),
		footer,
	)

	body := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, mainPanel)
	return m.styles.App.Render(lipgloss.JoinVertical(lipgloss.Left, header, body))
}

func (m *Model) renderSidebar(width, height int) string {
	m.list.SetSize(max(12, width-6), max(8, height-4))
	content := lipgloss.JoinVertical(
		lipgloss.Left,
		m.styles.PanelTitle.Render("Operations"),
		m.styles.PanelBody.Width(max(10, width-6)).Render("Pick a tool with the arrow keys. The preview updates as you type."),
		"",
		m.list.View(),
	)
	return m.styles.Panel.Width(width).Height(height).Render(content)
}

func (m *Model) renderForm(width int) string {
	op := m.selectedOperation()
	blocks := []string{
		m.styles.PanelTitle.Render(op.Title),
		m.styles.PanelBody.Width(max(10, width-6)).Render(op.Description),
	}

	for i, field := range op.Fields {
		label := m.styles.FieldLabel
		if i == m.activeInput {
			label = m.styles.FieldLabelOn
		}
		blocks = append(blocks,
			"",
			label.Render(field.Label),
			m.inputs[i].View(),
			m.styles.FieldHint.Width(max(10, width-6)).Render(field.Hint),
		)
	}

	return m.styles.Panel.Width(width).Render(lipgloss.JoinVertical(lipgloss.Left, blocks...))
}

func (m *Model) renderPreview(width int) string {
	resultStyle := m.styles.Result
	if m.preview.Error {
		resultStyle = m.styles.ResultErr
	}

	content := lipgloss.JoinVertical(
		lipgloss.Left,
		m.styles.PanelTitle.Render(m.preview.Title),
		resultStyle.Width(max(10, width-6)).Render(m.preview.Body),
		"",
		m.styles.Note.Width(max(10, width-6)).Render(m.preview.Note),
	)

	return m.styles.Panel.Width(width).Render(content)
}

func (m *Model) resize() {
	inputWidth := max(20, m.formInnerWidth())
	for i := range m.inputs {
		m.inputs[i].Width = inputWidth
	}
	m.help.Width = max(30, m.width-8)
}

func (m *Model) formInnerWidth() int {
	if m.width < 92 {
		return m.width - 12
	}
	sidebarWidth := clamp(m.width/3, 28, 34)
	return m.width - sidebarWidth - 14
}

func (m *Model) selectedOperation() operation {
	selected, ok := m.list.SelectedItem().(operationItem)
	if !ok {
		return m.operations[0]
	}
	return selected.operation
}

func (m *Model) syncInputs() {
	op := m.selectedOperation()
	currentValues := m.ensureValueSlots(op.ID, len(op.Fields))
	m.inputs = make([]textinput.Model, len(op.Fields))

	for i, field := range op.Fields {
		input := textinput.New()
		input.Prompt = "› "
		input.Placeholder = field.Placeholder
		input.SetValue(currentValues[i])
		input.CharLimit = 256
		input.Width = max(20, m.formInnerWidth())
		input.Cursor.Style = lipgloss.NewStyle().Foreground(colorAccentCool)
		input.PromptStyle = lipgloss.NewStyle().Foreground(colorAccentWarm)
		input.PlaceholderStyle = lipgloss.NewStyle().Foreground(colorSubtle)
		input.TextStyle = lipgloss.NewStyle().Foreground(colorText)
		m.inputs[i] = input
	}

	m.applyInputStyles()
}

func (m *Model) syncInputFocus() tea.Cmd {
	if len(m.inputs) == 0 {
		return nil
	}

	var cmds []tea.Cmd
	for i := range m.inputs {
		if i == m.activeInput {
			cmds = append(cmds, m.inputs[i].Focus())
		} else {
			m.inputs[i].Blur()
		}
	}

	m.applyInputStyles()
	return tea.Batch(cmds...)
}

func (m *Model) applyInputStyles() {
	for i := range m.inputs {
		if i == m.activeInput {
			m.inputs[i].PromptStyle = lipgloss.NewStyle().Foreground(colorAccentWarm).Bold(true)
			m.inputs[i].TextStyle = lipgloss.NewStyle().Foreground(colorText)
		} else {
			m.inputs[i].PromptStyle = lipgloss.NewStyle().Foreground(colorMuted)
			m.inputs[i].TextStyle = lipgloss.NewStyle().Foreground(colorMuted)
		}
	}
}

func (m *Model) nextInput() {
	if len(m.inputs) == 0 {
		return
	}
	m.activeInput = (m.activeInput + 1) % len(m.inputs)
}

func (m *Model) previousInput() {
	if len(m.inputs) == 0 {
		return
	}
	m.activeInput--
	if m.activeInput < 0 {
		m.activeInput = len(m.inputs) - 1
	}
}

func (m *Model) clearCurrentOperation() {
	op := m.selectedOperation()
	values := m.ensureValueSlots(op.ID, len(op.Fields))
	for i := range values {
		values[i] = ""
	}
	for i := range m.inputs {
		m.inputs[i].SetValue("")
	}
}

func (m *Model) ensureValueSlots(id operationID, size int) []string {
	current := m.values[id]
	if len(current) == size {
		return current
	}

	resized := make([]string, size)
	copy(resized, current)
	m.values[id] = resized
	return resized
}

func (m *Model) storeInputValues() {
	op := m.selectedOperation()
	values := m.ensureValueSlots(op.ID, len(m.inputs))
	for i := range m.inputs {
		values[i] = m.inputs[i].Value()
	}
}

func (m *Model) refreshPreview() {
	op := m.selectedOperation()
	values := m.ensureValueSlots(op.ID, len(op.Fields))
	m.preview = evaluatePreview(op, values)
}

func defaultOperations() []operation {
	return []operation{
		{
			ID:          opJoin,
			Title:       "Join Paths",
			Description: "Combine multiple path fragments into one platform-aware path.",
			Fields: []fieldDefinition{{
				Label:        "Fragments",
				InitialValue: "src | assets | logo.svg",
				Placeholder:  "src | assets | logo.svg",
				Hint:         "Separate each path part with a vertical bar.",
			}},
		},
		{
			ID:          opClean,
			Title:       "Clean Path",
			Description: "Collapse duplicate separators and resolve dots in a path.",
			Fields: []fieldDefinition{{
				Label:        "Path",
				InitialValue: "./tmp/../tmp/build",
				Placeholder:  "./tmp/../tmp/build",
				Hint:         "Great for normalizing user-provided paths.",
			}},
		},
		{
			ID:          opAbs,
			Title:       "Absolute Path",
			Description: "Resolve a path against the current working directory.",
			Fields: []fieldDefinition{{
				Label:        "Path",
				InitialValue: "README.MD",
				Placeholder:  "README.MD",
				Hint:         "The result uses the shell's current directory as the base.",
			}},
		},
		{
			ID:          opBase,
			Title:       "Base Name",
			Description: "Extract the final element from a path.",
			Fields: []fieldDefinition{{
				Label:        "Path",
				InitialValue: "/tmp/demo/file.txt",
				Placeholder:  "/tmp/demo/file.txt",
				Hint:         "Useful when you need just the file or leaf directory name.",
			}},
		},
		{
			ID:          opDir,
			Title:       "Directory",
			Description: "Return everything in a path except the final element.",
			Fields: []fieldDefinition{{
				Label:        "Path",
				InitialValue: "/tmp/demo/file.txt",
				Placeholder:  "/tmp/demo/file.txt",
				Hint:         "Use this when you need the parent directory portion only.",
			}},
		},
		{
			ID:          opEnvExport,
			Title:       "Export Env",
			Description: "Generate a shell command that sets a temporary environment variable.",
			Fields: []fieldDefinition{
				{
					Label:        "Variable Name",
					InitialValue: "PROJECT_ROOT",
					Placeholder:  "PROJECT_ROOT",
					Hint:         "Use letters, digits, and underscores only.",
				},
				{
					Label:        "Value",
					InitialValue: "/tmp/project",
					Placeholder:  "/tmp/project",
					Hint:         "This becomes the value assigned by the generated shell command.",
				},
				{
					Label:        "Shell",
					InitialValue: "auto",
					Placeholder:  "auto",
					Hint:         "Supported values: auto, sh, powershell, cmd.",
				},
			},
		},
		{
			ID:          opEnvUnset,
			Title:       "Unset Env",
			Description: "Generate a shell command that removes an environment variable.",
			Fields: []fieldDefinition{
				{
					Label:        "Variable Name",
					InitialValue: "PROJECT_ROOT",
					Placeholder:  "PROJECT_ROOT",
					Hint:         "The preview will reject invalid variable names immediately.",
				},
				{
					Label:        "Shell",
					InitialValue: "auto",
					Placeholder:  "auto",
					Hint:         "Supported values: auto, sh, powershell, cmd.",
				},
			},
		},
	}
}

func defaultKeys() keyMap {
	return keyMap{
		Up:    key.NewBinding(key.WithKeys("up"), key.WithHelp("up", "operation")),
		Down:  key.NewBinding(key.WithKeys("down"), key.WithHelp("down", "operation")),
		Next:  key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "next field")),
		Prev:  key.NewBinding(key.WithKeys("shift+tab"), key.WithHelp("shift+tab", "prev field")),
		Reset: key.NewBinding(key.WithKeys("ctrl+r"), key.WithHelp("ctrl+r", "reset")),
		Quit:  key.NewBinding(key.WithKeys("esc", "ctrl+c"), key.WithHelp("esc", "quit")),
	}
}

func evaluatePreview(op operation, values []string) previewState {
	switch op.ID {
	case opJoin:
		parts := splitJoinParts(values[0])
		if len(parts) == 0 {
			return pendingPreview("Computed Path", "Add fragments separated by | to see the combined path.")
		}
		return previewState{
			Title: "Computed Path",
			Body:  pathvador.Join(parts...),
			Note:  "The separator follows the OS running path_vador.",
		}
	case opClean:
		path := strings.TrimSpace(values[0])
		if path == "" {
			return pendingPreview("Cleaned Path", "Enter a path to normalize it.")
		}
		return previewState{
			Title: "Cleaned Path",
			Body:  pathvador.Clean(path),
			Note:  "Dots and duplicate separators are collapsed using Go's filepath rules.",
		}
	case opAbs:
		path := strings.TrimSpace(values[0])
		if path == "" {
			return pendingPreview("Absolute Path", "Enter a path to resolve it from the current working directory.")
		}
		absolutePath, err := pathvador.Abs(path)
		if err != nil {
			return errorPreview("Absolute Path Error", err.Error())
		}
		return previewState{
			Title: "Absolute Path",
			Body:  absolutePath,
			Note:  "Resolution happens relative to the directory where you launched path_vador.",
		}
	case opBase:
		path := strings.TrimSpace(values[0])
		if path == "" {
			return pendingPreview("Base Name", "Enter a path to extract the last segment.")
		}
		return previewState{
			Title: "Base Name",
			Body:  pathvador.Base(path),
			Note:  "Useful when you only need the file or folder at the end of a path.",
		}
	case opDir:
		path := strings.TrimSpace(values[0])
		if path == "" {
			return pendingPreview("Directory", "Enter a path to show its parent directory.")
		}
		return previewState{
			Title: "Directory",
			Body:  pathvador.Dir(path),
			Note:  "This removes the final element and keeps the parent directory path.",
		}
	case opEnvExport:
		name := strings.TrimSpace(values[0])
		value := values[1]
		shell := sanitizeShell(values[2])
		if name == "" {
			return pendingPreview("Shell Command", "Enter a variable name to generate a command.")
		}
		resolvedShell, err := pathvador.ResolveShell(shell, runtime.GOOS, os.Getenv)
		if err != nil {
			return errorPreview("Shell Command Error", err.Error())
		}
		command, err := pathvador.ExportCommand(resolvedShell, name, value)
		if err != nil {
			return errorPreview("Shell Command Error", err.Error())
		}
		return previewState{
			Title: "Shell Command",
			Body:  command,
			Note:  fmt.Sprintf("Evaluate this in %s to affect the current shell session.", resolvedShell),
		}
	case opEnvUnset:
		name := strings.TrimSpace(values[0])
		shell := sanitizeShell(values[1])
		if name == "" {
			return pendingPreview("Shell Command", "Enter a variable name to generate an unset command.")
		}
		resolvedShell, err := pathvador.ResolveShell(shell, runtime.GOOS, os.Getenv)
		if err != nil {
			return errorPreview("Shell Command Error", err.Error())
		}
		command, err := pathvador.UnsetCommand(resolvedShell, name)
		if err != nil {
			return errorPreview("Shell Command Error", err.Error())
		}
		return previewState{
			Title: "Shell Command",
			Body:  command,
			Note:  fmt.Sprintf("Run this in %s when you want to remove the variable from the current session.", resolvedShell),
		}
	default:
		return errorPreview("Preview Error", "Unknown operation selected.")
	}
}

func pendingPreview(title, note string) previewState {
	return previewState{
		Title: title,
		Body:  "Waiting for input…",
		Note:  note,
	}
}

func errorPreview(title, message string) previewState {
	return previewState{
		Title: title,
		Body:  message,
		Note:  "Update the current field values to clear the validation error.",
		Error: true,
	}
}

func sanitizeShell(shell string) string {
	shell = strings.TrimSpace(shell)
	if shell == "" {
		return "auto"
	}
	return shell
}

func splitJoinParts(raw string) []string {
	chunks := strings.Split(raw, "|")
	parts := make([]string, 0, len(chunks))
	for _, chunk := range chunks {
		part := strings.TrimSpace(chunk)
		if part != "" {
			parts = append(parts, part)
		}
	}
	return parts
}

func defaultStyles() styles {
	return styles{
		App: lipgloss.NewStyle().
			Padding(1, 2).
			Foreground(colorText),
		Header: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colorBorder).
			Background(colorPanel).
			Padding(1, 2).
			MarginBottom(1),
		Title: lipgloss.NewStyle().
			Bold(true).
			Foreground(colorAccentWarm),
		Subtitle: lipgloss.NewStyle().
			Foreground(colorMuted),
		Panel: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colorBorder).
			Background(colorPanel).
			Padding(1, 2).
			Margin(0, 1, 1, 0),
		PanelTitle: lipgloss.NewStyle().
			Foreground(colorAccentCool).
			Bold(true),
		PanelBody: lipgloss.NewStyle().
			Foreground(colorMuted),
		FieldLabel: lipgloss.NewStyle().
			Foreground(colorMuted),
		FieldLabelOn: lipgloss.NewStyle().
			Foreground(colorAccentWarm).
			Bold(true),
		FieldHint: lipgloss.NewStyle().
			Foreground(colorSubtle),
		Result: lipgloss.NewStyle().
			Foreground(colorText).
			Background(colorOutput).
			Padding(1, 1),
		ResultErr: lipgloss.NewStyle().
			Foreground(colorError).
			Background(colorOutput).
			Padding(1, 1),
		Note: lipgloss.NewStyle().
			Foreground(colorMuted),
		Footer: lipgloss.NewStyle().
			Foreground(colorMuted),
	}
}

func (m *Model) seedDefaultValues() {
	for _, op := range m.operations {
		values := make([]string, len(op.Fields))
		for i, field := range op.Fields {
			values[i] = field.InitialValue
		}
		m.values[op.ID] = values
	}
}

var (
	colorText       = lipgloss.AdaptiveColor{Light: "#2D211A", Dark: "#F7EFE4"}
	colorMuted      = lipgloss.AdaptiveColor{Light: "#7B6A5D", Dark: "#C9B8A9"}
	colorSubtle     = lipgloss.AdaptiveColor{Light: "#9C8B7D", Dark: "#9F9185"}
	colorBorder     = lipgloss.AdaptiveColor{Light: "#D7C3B1", Dark: "#5A493F"}
	colorPanel      = lipgloss.AdaptiveColor{Light: "#FFFDF8", Dark: "#161210"}
	colorOutput     = lipgloss.AdaptiveColor{Light: "#F7F1E8", Dark: "#201A17"}
	colorAccentWarm = lipgloss.AdaptiveColor{Light: "#C35B2A", Dark: "#F2A36E"}
	colorAccentCool = lipgloss.AdaptiveColor{Light: "#12746D", Dark: "#7AD7C7"}
	colorError      = lipgloss.AdaptiveColor{Light: "#B42318", Dark: "#FF8A70"}
)

func clamp(value, low, high int) int {
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}
