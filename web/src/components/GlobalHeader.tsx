import { useState } from 'react'
import { Menu, X, BarChart2, History, Settings, LogOut, Home } from 'lucide-react'

interface GlobalHeaderProps {
  onNavigate: (view: any) => void
  onLogout: () => void
  currentView: string
}

export function GlobalHeader({ onNavigate, onLogout, currentView }: GlobalHeaderProps) {
  const [isOpen, setIsOpen] = useState(false)

  const menuItems = [
    { label: 'Home', icon: Home, view: 'home' },
    { label: 'Progress', icon: BarChart2, view: 'progress' },
    { label: 'History', icon: History, view: 'workout-history' },
    { label: 'Settings', icon: Settings, view: 'settings' },
  ]

  const handleNavigate = (view: string) => {
    onNavigate({ view })
    setIsOpen(false)
  }

  return (
    <>
      <div className="flex items-center justify-between p-4 bg-background sticky top-0 z-50 max-w-2xl mx-auto w-full">
        <button 
          onClick={() => handleNavigate('home')}
          className="text-3xl font-bold tracking-tighter hover:opacity-80 transition-opacity"
        >
          LIFT
        </button>
        
        <button 
          onClick={() => setIsOpen(true)}
          className="p-2 hover:bg-muted rounded-md transition-colors"
        >
          <Menu className="w-6 h-6" />
        </button>
      </div>

      {/* Mobile Menu Overlay */}
      {isOpen && (
        <div className="fixed inset-0 z-[100] bg-background animate-in fade-in slide-in-from-right duration-200">
          <div className="flex flex-col h-full max-w-2xl mx-auto">
            <div className="flex items-center justify-between p-4">
              <span className="text-3xl font-bold tracking-tighter">MENU</span>
              <button 
                onClick={() => setIsOpen(false)}
                className="p-2 hover:bg-muted rounded-md transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="flex-1 px-4 py-8 space-y-2">
              {menuItems.map((item) => (
                <button
                  key={item.label}
                  onClick={() => handleNavigate(item.view)}
                  className={`w-full flex items-center gap-4 p-4 rounded-xl transition-all ${
                    currentView === item.view 
                      ? 'bg-primary text-primary-foreground shadow-lg shadow-primary/20' 
                      : 'hover:bg-muted text-foreground'
                  }`}
                >
                  <item.icon className="w-5 h-5" />
                  <span className="text-lg font-black uppercase tracking-tight">{item.label}</span>
                </button>
              ))}
            </div>

            <div className="p-4 border-t border-border">
              <button
                onClick={() => {
                  onLogout()
                  setIsOpen(false)
                }}
                className="w-full flex items-center gap-4 p-4 rounded-xl hover:bg-destructive/10 text-destructive transition-all"
              >
                <LogOut className="w-5 h-5" />
                <span className="text-lg font-black uppercase tracking-tight">Logout</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
