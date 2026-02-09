import * as React from "react"
import { X } from "lucide-react"
import { Button } from "./button"
import { Card } from "./card"
import { cn } from "@/lib/utils"

interface ModalProps {
  children: React.ReactNode
  onClose: () => void
  title?: string
  description?: string
  className?: string
  headerClassName?: string
  closeButtonClassName?: string
}

export function Modal({ 
  children, 
  onClose, 
  title, 
  description,
  className,
  headerClassName,
  closeButtonClassName
}: ModalProps) {
  React.useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleEsc)
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', handleEsc)
      document.body.style.overflow = ''
    }
  }, [onClose])

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6">
      {/* Backdrop */}
      <div 
        className="fixed inset-0 bg-black/40 backdrop-blur-[2px] animate-in fade-in duration-300" 
        onClick={onClose} 
      />
      
      {/* Modal Content */}
      <Card 
        className={cn(
          "relative w-full shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-bottom-4 duration-300 flex flex-col max-h-[90vh] overflow-hidden",
          className
        )}
        onClick={(e) => e.stopPropagation()}
      >
        <div className={cn("flex items-center justify-between p-4 border-b shrink-0", headerClassName)}>
          <div className="flex flex-col gap-1 pr-4 min-w-0">
            {title && <h2 className="text-lg font-bold truncate">{title}</h2>}
            {description && <p className="text-sm text-muted-foreground">{description}</p>}
          </div>
          <Button 
            variant="ghost" 
            size="icon" 
            className={cn("h-8 w-8 rounded-full shrink-0", closeButtonClassName)} 
            onClick={onClose}
          >
            <X className="w-4 h-4" />
          </Button>
        </div>
        
        <div className="flex-1 overflow-y-auto">
          {children}
        </div>
      </Card>
    </div>
  )
}
