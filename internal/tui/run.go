package tui

import tea "github.com/charmbracelet/bubbletea"

// Run launches the default Bubble Tea interface in the alternate screen.
func Run() error {
	program := tea.NewProgram(NewModel(), tea.WithAltScreen())
	_, err := program.Run()
	return err
}
