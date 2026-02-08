import { useState, useEffect } from 'react'

export function useElapsed(startSecs: number | bigint) {
  const start = Number(startSecs)
  const [elapsed, setElapsed] = useState(() => Math.floor(Date.now() / 1000) - start)
  
  useEffect(() => {
    if (start === 0) return
    const update = () => setElapsed(Math.floor(Date.now() / 1000) - start)
    update()
    const id = setInterval(update, 1000)
    return () => clearInterval(id)
  }, [start])
  
  return start === 0 ? 0 : elapsed
}

export function useCountdown(untilSecs: number | bigint) {
  const until = Number(untilSecs)
  const [remaining, setRemaining] = useState(() => Math.max(0, until - Math.floor(Date.now() / 1000)))
  
  useEffect(() => {
    if (until === 0) return
    const update = () => setRemaining(Math.max(0, until - Math.floor(Date.now() / 1000)))
    update()
    const id = setInterval(update, 200)
    return () => clearInterval(id)
  }, [until])
  
  return until === 0 ? 0 : remaining
}

export function fmtElapsed(secs: number) {
  const h = Math.floor(secs / 3600)
  const m = Math.floor((secs % 3600) / 60)
  const s = secs % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}
