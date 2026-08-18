import { computed, inject, Injectable } from '@angular/core';
import { authState, Auth, signInWithEmailAndPassword, signOut, User } from '@angular/fire/auth';
import { toSignal } from '@angular/core/rxjs-interop';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly auth = inject(Auth);
  readonly authState$ = authState(this.auth);
  private readonly authStateSignal = toSignal(this.authState$, {
    initialValue: this.auth.currentUser,
  });

  readonly user = computed<User | null>(() => this.authStateSignal());
  readonly isAuthenticated = computed(() => this.user() !== null);

  signIn(email: string, password: string): Promise<void> {
    return signInWithEmailAndPassword(this.auth, email.trim(), password).then(() => undefined);
  }

  signOut(): Promise<void> {
    return signOut(this.auth);
  }
}
