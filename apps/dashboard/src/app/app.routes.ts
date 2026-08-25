import { Routes } from '@angular/router';

import { authGuard } from './core/auth/auth.guard';
import { DEFAULT_RESTAURANT_ID } from './shared/restaurant-context';

export const routes: Routes = [
  {
    path: '',
    pathMatch: 'full',
    redirectTo: `kitchen/${DEFAULT_RESTAURANT_ID}`,
  },
  {
    path: 'login',
    loadComponent: () =>
      import('./features/auth/presentation/login.component').then(
        ({ LoginComponent }) => LoginComponent,
      ),
  },
  {
    path: 'kitchen/:restaurantId',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./features/kitchen/presentation/components/kitchen-board.component').then(
        ({ KitchenBoardComponent }) => KitchenBoardComponent,
      ),
  },
  {
    path: 'menu',
    canActivate: [authGuard],
    canActivateChild: [authGuard],
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./features/menu/presentation/components/menu-management.component').then(
            ({ MenuManagementComponent }) => MenuManagementComponent,
          ),
      },
      {
        path: ':restaurantId',
        loadComponent: () =>
          import('./features/menu/presentation/components/menu-management.component').then(
            ({ MenuManagementComponent }) => MenuManagementComponent,
          ),
      },
    ],
  },
  {
    path: 'tables',
    canActivate: [authGuard],
    canActivateChild: [authGuard],
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./features/tables/presentation/components/table-management.component').then(
            ({ TableManagementComponent }) => TableManagementComponent,
          ),
      },
      {
        path: ':restaurantId',
        loadComponent: () =>
          import('./features/tables/presentation/components/table-management.component').then(
            ({ TableManagementComponent }) => TableManagementComponent,
          ),
      },
    ],
  },
  {
    path: '**',
    redirectTo: `kitchen/${DEFAULT_RESTAURANT_ID}`,
  },
];
