import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter } from '@angular/router';
import { getApp, initializeApp, provideFirebaseApp } from '@angular/fire/app';
import { getFirestore, provideFirestore } from '@angular/fire/firestore';
import { getFunctions, provideFunctions } from '@angular/fire/functions';

import { environment } from '../environments/environment';
import { KitchenRepository } from './features/kitchen/domain/kitchen-repository';
import { UpdateOrderStatusUseCase } from './features/kitchen/domain/use-cases/update-order-status.use-case';
import { WatchKitchenQueueUseCase } from './features/kitchen/domain/use-cases/watch-kitchen-queue.use-case';
import { KitchenRepositoryImpl } from './features/kitchen/data/kitchen-repository.impl';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideFirebaseApp(() => initializeApp(environment.firebase)),
    provideFirestore(() => getFirestore(getApp())),
    provideFunctions(() => getFunctions(getApp())),
    { provide: KitchenRepository, useClass: KitchenRepositoryImpl },
    { provide: WatchKitchenQueueUseCase, useClass: WatchKitchenQueueUseCase },
    { provide: UpdateOrderStatusUseCase, useClass: UpdateOrderStatusUseCase },
  ],
};
