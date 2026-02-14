import { Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

interface LoadingSpinnerProps {
  className?: string
  size?: 'sm' | 'md' | 'lg'
}

export function LoadingSpinner({ className, size = 'md' }: LoadingSpinnerProps) {
  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-6 h-6',
    lg: 'w-8 h-8',
  }

  return (
    <Loader2 
      className={cn(
        'animate-spin text-muted-foreground', 
        sizeClasses[size],
        className
      )} 
    />
  )
}

interface LoadingBlockProps {
  className?: string
  text?: string
}

export function LoadingBlock({ className, text = 'Loading...' }: LoadingBlockProps) {
  return (
    <div className={cn(
      'flex flex-col items-center justify-center py-12 gap-3 text-center',
      className
    )}>
      <LoadingSpinner size="lg" />
      {text && (
        <p className="text-xs font-black uppercase tracking-widest text-muted-foreground/50 animate-pulse">
          {text}
        </p>
      )}
    </div>
  )
}
