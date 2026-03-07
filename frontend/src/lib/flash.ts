const FLASH_KEY = "flash_message";

export type FlashType = "info" | "error";

export type FlashMessage = {
  text: string;
  type: FlashType;
};

export function setFlash(message: FlashMessage) {
  if (typeof window === "undefined") return;
  sessionStorage.setItem(FLASH_KEY, JSON.stringify(message));
}

export function consumeFlash(): FlashMessage | null {
  if (typeof window === "undefined") return null;

  const raw = sessionStorage.getItem(FLASH_KEY);
  if (!raw) return null;

  sessionStorage.removeItem(FLASH_KEY);

  try {
    const parsed = JSON.parse(raw) as FlashMessage;
    if (!parsed?.text) return null;
    return {
      text: parsed.text,
      type: parsed.type === "error" ? "error" : "info",
    };
  } catch {
    return null;
  }
}