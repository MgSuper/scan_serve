import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { submitOrder } from './callable/submit_order';
export { updateOrderStatus } from './callable/update_order_status';
