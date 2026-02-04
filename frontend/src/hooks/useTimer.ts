import { useState, useEffect, useRef } from "react";

export function useTimer() {
  const [now, setNow] = useState(() => Date.now());
  const rafRef = useRef<number>(0);

  useEffect(() => {
    const tick = () => {
      setNow(Date.now());
      rafRef.current = requestAnimationFrame(tick);
    };
    // Update every second instead of every frame for performance
    const interval = setInterval(() => setNow(Date.now()), 1000);
    return () => {
      clearInterval(interval);
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, []);

  const getElapsedSeconds = (since: Date): number => {
    return Math.max(0, Math.floor((now - since.getTime()) / 1000));
  };

  const getRemainingSeconds = (until: Date): number => {
    return Math.max(0, Math.ceil((until.getTime() - now) / 1000));
  };

  return { now, getElapsedSeconds, getRemainingSeconds };
}
