import { Injectable, OnDestroy } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class KitchenAudioNotificationService implements OnDestroy {
  private audioContext: AudioContext | null = null;

  playNewOrderCue(): void {
    if (typeof window === 'undefined' || typeof window.AudioContext === 'undefined') {
      return;
    }

    try {
      const context = this.audioContext ?? (this.audioContext = new window.AudioContext());
      void context
        .resume()
        .then(() => {
          const now = context.currentTime;
          this.playTone(context, now, 880, 0.08);
          this.playTone(context, now + 0.1, 1175, 0.12);
        })
        .catch(() => undefined);
    } catch {
      // Browsers can reject audio contexts until the user has interacted with the page.
    }
  }

  ngOnDestroy(): void {
    void this.audioContext?.close().catch(() => undefined);
  }

  private playTone(
    context: AudioContext,
    startTime: number,
    frequency: number,
    duration: number,
  ): void {
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(frequency, startTime);
    gain.gain.setValueAtTime(0.0001, startTime);
    gain.gain.exponentialRampToValueAtTime(0.18, startTime + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, startTime + duration);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(startTime);
    oscillator.stop(startTime + duration);
  }
}
