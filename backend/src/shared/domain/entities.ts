/** Framework-free business entities shared by backend and dashboard code. */
export interface AuditMetadata { createdAt: Date; updatedAt: Date; submittedAt?: Date; acceptedAt?: Date; preparedAt?: Date; servedAt?: Date; deletedAt?: Date; deletedBy?: string; isArchived: boolean; }
export interface Menu { id: string; restaurantId: string; branchId: string; name: string; description?: string; isActive: boolean; metadata: AuditMetadata; }
export interface Category { id: string; restaurantId: string; branchId: string; menuId: string; name: string; description?: string; displayOrder: number; isActive: boolean; metadata: AuditMetadata; }
export interface MenuItem { id: string; restaurantId: string; branchId: string; menuId: string; categoryId: string; name: string; description?: string; imageUrl?: string; price: number; displayOrder: number; isAvailable: boolean; metadata: AuditMetadata; }
export interface CartItem { menuItemId: string; name: string; unitPrice: number; quantity: number; note?: string; modifiers: readonly string[]; }
export interface Cart { id: string; restaurantId: string; branchId: string; tableId: string; tableSessionId: string; customerSessionId: string; items: readonly CartItem[]; metadata: AuditMetadata; }
export interface OrderItem { id: string; orderId: string; restaurantId: string; branchId: string; menuItemId: string; categoryId: string; name: string; unitPrice: number; quantity: number; note?: string; modifiers: readonly string[]; metadata: AuditMetadata; }
export type OrderStatus = 'PENDING' | 'ACCEPTED' | 'PREPARING' | 'READY' | 'SERVED' | 'CANCELLED';
export interface Order { id: string; restaurantId: string; branchId: string; tableId: string; tableSessionId: string; customerSessionId: string; status: OrderStatus; items: readonly OrderItem[]; customerNote?: string; metadata: AuditMetadata; }
export type TableSessionStatus = 'ACTIVE' | 'COMPLETED' | 'EXPIRED';
export interface TableSession { id: string; restaurantId: string; branchId: string; tableId: string; status: TableSessionStatus; customerCount: number; startedAt: Date; endedAt?: Date; expiresAt: Date; metadata: AuditMetadata; }
export type CustomerSessionStatus = 'ACTIVE' | 'INACTIVE' | 'EXPIRED';
export interface CustomerSession { id: string; restaurantId: string; branchId: string; tableId: string; tableSessionId: string; languageCode?: string; deviceId?: string; status: CustomerSessionStatus; lastActivityAt: Date; expiresAt: Date; metadata: AuditMetadata; }
