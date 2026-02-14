import { useState, useEffect } from 'react'
import { Menu, X, BarChart2, History, LogOut, Home, User, Sun, Moon, Key } from 'lucide-react'

interface GlobalHeaderProps {
  onNavigate: (view: any) => void
  onLogout: () => void
  currentView: string
  userName?: string
}

export function GlobalHeader({ onNavigate, onLogout, currentView, userName }: GlobalHeaderProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('lift-theme')
      if (saved) return saved === 'dark'
      return window.matchMedia('(prefers-color-scheme: dark)').matches
    }
    return false
  })

  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add('dark')
      localStorage.setItem('lift-theme', 'dark')
    } else {
      document.documentElement.classList.remove('dark')
      localStorage.setItem('lift-theme', 'light')
    }
  }, [isDark])

  const menuItems = [
    { label: 'Home', icon: Home, view: 'home' },
    { label: 'Progress', icon: BarChart2, view: 'progress' },
    { label: 'History', icon: History, view: 'workout-history' },
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

            <div className="flex-1 px-4 py-8 space-y-2 overflow-y-auto">
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

              <div className="pt-8 space-y-4">
                <button
                  onClick={() => handleNavigate('passkeys')}
                  className={`w-full flex items-center gap-4 p-4 rounded-xl transition-all ${
                    currentView === 'passkeys' 
                      ? 'bg-primary/10 text-primary border border-primary/20' 
                      : 'hover:bg-muted text-foreground border border-transparent'
                  }`}
                >
                  <Key className="w-5 h-5" />
                  <span className="text-lg font-black uppercase tracking-tight">Passkeys</span>
                </button>

                <button
                  onClick={() => setIsDark(!isDark)}
                  className="w-full flex items-center justify-between p-4 rounded-xl hover:bg-muted text-foreground transition-all border border-border/50"
                >
                  <div className="flex items-center gap-4">
                    {isDark ? <Moon className="w-5 h-5 text-blue-400" /> : <Sun className="w-5 h-5 text-amber-500" />}
                    <span className="text-lg font-black uppercase tracking-tight">
                      {isDark ? 'Dark Mode' : 'Light Mode'}
                    </span>
                  </div>
                  <div className={`w-10 h-6 rounded-full p-1 transition-colors ${isDark ? 'bg-primary' : 'bg-muted-foreground/30'}`}>
                    <div className={`w-4 h-4 rounded-full transition-transform ${isDark ? 'translate-x-4 bg-primary-foreground' : 'bg-white'}`} />
                  </div>
                </button>
              </div>
            </div>

            <div className="p-4 border-t border-border space-y-2">
              {userName && (
                <div className="flex items-center gap-4 px-4 py-2 text-muted-foreground">
                  <User className="w-5 h-5" />
                  <span className="text-sm font-black uppercase tracking-widest truncate">{userName}</span>
                </div>
              )}
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
