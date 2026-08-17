import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    pathMatch: 'full',
    redirectTo: 'kitchen/scanserve-demo',
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
    redirectTo: 'kitchen/scanserve-demo',
  },
];
