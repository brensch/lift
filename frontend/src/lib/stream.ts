export async function createInflappableStream<T>(
  startStream: (signal: AbortSignal) => AsyncIterable<T>,
  onMessage: (msg: T) => void,
  onError?: (err: unknown) => void,
  signal?: AbortSignal,
): Promise<void> {
  let backoff = 1000;
  const maxBackoff = 30000;

  while (!signal?.aborted) {
    try {
      const controller = new AbortController();

      if (signal) {
        signal.addEventListener("abort", () => controller.abort(), {
          once: true,
        });
      }

      const stream = startStream(controller.signal);
      backoff = 1000;

      for await (const msg of stream) {
        if (signal?.aborted) return;
        onMessage(msg);
      }

      // Stream ended normally, reconnect
      if (signal?.aborted) return;
    } catch (err) {
      if (signal?.aborted) return;
      onError?.(err);
    }

    // Wait before reconnecting
    await new Promise((resolve) => {
      const timer = setTimeout(resolve, backoff);
      if (signal) {
        signal.addEventListener("abort", () => {
          clearTimeout(timer);
          resolve(undefined);
        }, { once: true });
      }
    });
    backoff = Math.min(backoff * 2, maxBackoff);
  }
}
