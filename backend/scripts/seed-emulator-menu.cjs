const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || 'scanserve-app-1010';
const DEFAULT_RESTAURANT_ID = 'scanserve-demo';
const DEFAULT_BRANCH_ID = 'main-branch';
const restaurantId = process.env.SCAN_SERVE_RESTAURANT_ID || DEFAULT_RESTAURANT_ID;
const branchId = process.env.SCAN_SERVE_BRANCH_ID || DEFAULT_BRANCH_ID;

process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';
const staffEmail = process.env.SCAN_SERVE_STAFF_EMAIL || 'staff@scanserve.com';
const staffPassword = process.env.SCAN_SERVE_STAFF_PASSWORD || 'password124';
initializeApp({ projectId });
const firestore = getFirestore();
const auth = getAuth();

const menuItems = [
  {
    id: 'default-pho-bo',
    category: 'Mains',
    categoryId: 'mains',
    categoryName: 'Mains',
    name: 'Phở bò',
    description: 'Slow-simmered beef noodle soup',
    price: 85000,
    imageUrl: 'https://placehold.co/640x480/png?text=Pho+Bo',
  },
  {
    id: 'default-bun-cha',
    category: 'Mains',
    categoryId: 'mains',
    categoryName: 'Mains',
    name: 'Bún chả',
    description: 'Grilled pork with rice noodles',
    price: 79000,
    imageUrl: 'https://placehold.co/640x480/png?text=Bun+Cha',
  },
  {
    id: 'default-spicy-noodles',
    category: 'Mains',
    categoryId: 'mains',
    categoryName: 'Mains',
    name: 'Spicy Noodles',
    description: 'Wok-tossed egg noodles with chilli and garlic',
    price: 72000,
    imageUrl: 'https://placehold.co/640x480/png?text=Spicy+Noodles',
  },
  {
    id: 'default-spring-rolls',
    category: 'Starters',
    categoryId: 'starters',
    categoryName: 'Starters',
    name: 'Spring rolls',
    description: 'Fresh herbs, prawns, and peanut sauce',
    price: 55000,
    imageUrl: 'https://placehold.co/640x480/png?text=Spring+Rolls',
  },
  {
    id: 'default-fruit-yogurt',
    category: 'Desserts',
    categoryId: 'desserts',
    categoryName: 'Desserts',
    name: 'Fruit Yogurt',
    description: 'Creamy yogurt with seasonal tropical fruits',
    price: 42000,
    imageUrl: 'https://placehold.co/640x480/png?text=Fruit+Yogurt',
  },
  {
    id: 'default-iced-coffee',
    category: 'Drinks',
    categoryId: 'drinks',
    categoryName: 'Drinks',
    name: 'Iced coffee',
    description: 'Robusta coffee with condensed milk',
    price: 35000,
    imageUrl: 'https://placehold.co/640x480/png?text=Iced+Coffee',
  },
  {
    id: 'default-lime-soda',
    category: 'Drinks',
    categoryId: 'drinks',
    categoryName: 'Drinks',
    name: 'Lime soda',
    description: 'Fresh lime and sparkling water',
    price: 30000,
    imageUrl: 'https://placehold.co/640x480/png?text=Lime+Soda',
  },
];

async function seedStaffProfile() {
  let user;
  try {
    user = await auth.getUserByEmail(staffEmail);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({ email: staffEmail, password: staffPassword, emailVerified: true });
  }
  const now = FieldValue.serverTimestamp();
  const roleId = 'role-demo-kitchen-staff';
  const role = {
    id: roleId,
    name: 'kitchen_staff',
    displayName: 'Kitchen Staff',
    restaurantId,
    branchId,
    permissions: ['orders.updateStatus'],
    isActive: true,
    isArchived: false,
    deletedAt: null,
    createdAt: now,
    updatedAt: now,
  };
  const staff = {
    id: user.uid,
    authUid: user.uid,
    email: staffEmail,
    displayName: 'Demo Kitchen Staff',
    restaurantId,
    branchId,
    roleId,
    isActive: true,
    isArchived: false,
    deletedAt: null,
    createdAt: now,
    updatedAt: now,
  };
  const batch = firestore.batch();
  batch.set(firestore.collection('roles').doc(roleId), role, { merge: true });
  batch.set(firestore.collection('staff').doc(user.uid), staff, { merge: true });
  batch.set(
    firestore.collection('restaurants').doc(restaurantId).collection('staff').doc(user.uid),
    staff,
    { merge: true },
  );
  await batch.commit();
  console.log(`[firestore-emulator] Seeded active ${role.name} profile for ${staffEmail} (${user.uid}) at ${restaurantId}/${branchId}.`);
}

async function seedMenu() {
  await seedStaffProfile();
  const batch = firestore.batch();
  const now = FieldValue.serverTimestamp();
  const restaurantReference = firestore.collection('restaurants').doc(restaurantId);
  const branchReference = restaurantReference.collection('branches').doc(branchId);
  const nestedMenu = restaurantReference.collection('menu');
  batch.set(
    restaurantReference,
    {
      id: restaurantId,
      name: restaurantId,
      defaultBranchId: branchId,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );
  batch.set(
    branchReference,
    {
      id: branchId,
      restaurantId,
      name: branchId,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  for (const item of menuItems) {
    const common = {
      id: item.id,
      restaurantId,
      branchId,
      name: item.name,
      description: item.description,
      category: item.category,
      categoryId: item.categoryId,
      categoryName: item.categoryName || item.category,
      imageUrl: item.imageUrl || null,
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
