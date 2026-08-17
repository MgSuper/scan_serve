import { Routes } from '@angular/router';

import { DEFAULT_RESTAURANT_ID } from './shared/restaurant-context';

export const routes: Routes = [
  {
    path: '',
    pathMatch: 'full',
    redirectTo: `kitchen/${DEFAULT_RESTAURANT_ID}`,
  },
  {
    path: 'kitchen/:restaurantId',
    loadComponent: () =>
      import('./features/kitchen/presentation/components/kitchen-board.component').then(
        ({ KitchenBoardComponent }) => KitchenBoardComponent,
      ),
  },
  {
    path: 'menu/:restaurantId',
    loadComponent: () =>
      import('./features/menu/presentation/components/menu-management.component').then(
        ({ MenuManagementComponent }) => MenuManagementComponent,
      ),
  },
  {
    path: '**',
    redirectTo: `kitchen/${DEFAULT_RESTAURANT_ID}`,
  },
];
