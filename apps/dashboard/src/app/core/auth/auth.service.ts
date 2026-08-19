import { computed, inject, Injectable } from '@angular/core';
import { authState, Auth, signInWithEmailAndPassword, signOut, User } from '@angular/fire/auth';
import { toSignal } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly auth = inject(Auth);
  private readonly router = inject(Router);
  readonly authState$ = authState(this.auth);
  private readonly authStateSignal = toSignal(this.authState$, {
    initialValue: this.auth.currentUser,
  });

  readonly user = computed<User | null>(() => this.authStateSignal());
  readonly isAuthenticated = computed(() => this.user() !== null);

  signIn(email: string, password: string): Promise<void> {
    return signInWithEmailAndPassword(this.auth, email.trim(), password).then(() => undefined);
  }

  async signOut(): Promise<void> {
    await signOut(this.auth);
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.clear();
    }
    await this.router.navigateByUrl('/login');
  }
}
