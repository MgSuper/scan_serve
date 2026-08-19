import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterLink, RouterOutlet } from '@angular/router';

import { AuthService } from './core/auth/auth.service';
import { DEFAULT_RESTAURANT_ID } from './shared/restaurant-context';

@Component({
  selector: 'app-root',
  imports: [RouterLink, RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class App {
  readonly defaultRestaurantId = DEFAULT_RESTAURANT_ID;
  readonly authService = inject(AuthService);

  async logout(): Promise<void> {
    await this.authService.signOut();
  }
}
