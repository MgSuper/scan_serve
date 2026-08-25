import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

import { KitchenRepository } from '../kitchen-repository';

@Injectable({ providedIn: 'root' })
export class ResolveAssistanceRequestUseCase {
  constructor(private readonly repository: KitchenRepository) {}

  execute(restaurantId: string, requestId: string): Observable<void> {
    if (!restaurantId.trim() || !requestId.trim()) {
      throw new Error('Restaurant and assistance request identifiers are required.');
    }
    return this.repository.resolveAssistanceRequest(restaurantId, requestId);
  }
}
