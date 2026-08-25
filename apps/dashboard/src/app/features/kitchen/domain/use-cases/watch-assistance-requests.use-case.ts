import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

import { KitchenRepository } from '../kitchen-repository';
import { StaffAssistanceRequest } from '../staff-assistance-request';

@Injectable({ providedIn: 'root' })
export class WatchAssistanceRequestsUseCase {
  constructor(private readonly repository: KitchenRepository) {}

  execute(restaurantId: string): Observable<readonly StaffAssistanceRequest[]> {
    if (!restaurantId.trim()) {
      throw new Error('Restaurant identifier is required.');
    }
    return this.repository.watchAssistanceRequests(restaurantId);
  }
}
