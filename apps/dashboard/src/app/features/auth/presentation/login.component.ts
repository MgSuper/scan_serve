import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { DEFAULT_RESTAURANT_ID } from '../../../shared/restaurant-context';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LoginComponent {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  readonly submitting = signal(false);
  readonly error = signal<string | null>(null);
  readonly redirectUrl = this.safeRedirect(this.route.snapshot.queryParamMap.get('redirect'));

  email = '';
  password = '';

  async submit(form: NgForm): Promise<void> {
    if (form.invalid || this.submitting()) {
      form.control.markAllAsTouched();
      return;
    }

    this.submitting.set(true);
    this.error.set(null);
    try {
      await this.authService.signIn(this.email, this.password);
      await this.router.navigateByUrl(this.redirectUrl);
    } catch (error: unknown) {
      this.error.set(this.messageFor(error));
      this.submitting.set(false);
    }
  }

  private safeRedirect(value: string | null): string {
    return value?.startsWith('/') && !value.startsWith('//')
      ? value
      : `/kitchen/${DEFAULT_RESTAURANT_ID}`;
  }

  private messageFor(error: unknown): string {
    const code = typeof error === 'object' && error !== null && 'code' in error ? error.code : null;
    switch (code) {
      case 'auth/invalid-credential':
      case 'auth/user-not-found':
      case 'auth/wrong-password':
        return 'The email or password is not recognised.';
      case 'auth/too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'auth/network-request-failed':
        return 'Unable to reach Firebase Authentication. Check your connection.';
      default:
        return 'We could not sign you in. Please check your details and try again.';
    }
  }
}
