const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || 'scanserve-app-1010';
const restaurantId = process.env.SCAN_SERVE_RESTAURANT_ID || 'scanserve-demo';
const branchId = process.env.SCAN_SERVE_BRANCH_ID || 'main-branch';

process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
initializeApp({ projectId });
const firestore = getFirestore();

const menuItems = [
  {
    id: 'default-pho-bo',
    category: 'Mains',
    categoryId: 'mains',
    name: 'Phở bò',
    description: 'Slow-simmered beef noodle soup',
    price: 85000,
  },
  {
    id: 'default-bun-cha',
    category: 'Mains',
    categoryId: 'mains',
    name: 'Bún chả',
    description: 'Grilled pork with rice noodles',
    price: 79000,
  },
  {
    id: 'default-spring-rolls',
    category: 'Starters',
    categoryId: 'starters',
    name: 'Spring rolls',
    description: 'Fresh herbs, prawns, and peanut sauce',
    price: 55000,
  },
  {
    id: 'default-iced-coffee',
    category: 'Drinks',
    categoryId: 'drinks',
    name: 'Iced coffee',
    description: 'Robusta coffee with condensed milk',
    price: 35000,
  },
  {
    id: 'default-lime-soda',
    category: 'Drinks',
    categoryId: 'drinks',
    name: 'Lime soda',
    description: 'Fresh lime and sparkling water',
    price: 30000,
  },
];

async function seedMenu() {
  const batch = firestore.batch();
  const now = FieldValue.serverTimestamp();
  const nestedMenu = firestore.collection('restaurants').doc(restaurantId).collection('menu');

  for (const item of menuItems) {
    const common = {
      id: item.id,
      restaurantId,
      branchId,
      name: item.name,
      description: item.description,
      category: item.category,
      categoryId: item.categoryId,
      price: item.price,
      status: 'in_stock',
      availability: 'in_stock',
      isAvailable: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    };
    batch.set(nestedMenu.doc(item.id), common, { merge: true });
    batch.set(firestore.collection('menuItems').doc(item.id), common, { merge: true });
  }

  await batch.commit();
  console.log(`[firestore-emulator] Seeded ${menuItems.length} menu items for ${restaurantId}/${branchId}.`);
}

seedMenu().catch((error) => {
  console.error('[firestore-emulator] Menu seed failed:', error);
  process.exitCode = 1;
});
