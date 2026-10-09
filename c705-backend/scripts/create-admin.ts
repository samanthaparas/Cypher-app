import * as bcrypt from 'bcrypt';
import { PrismaClient } from '../../c705_db/generated/prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL must be set in the environment (.env)');
}

const prisma = new PrismaClient({
  adapter: new PrismaPg(
    new Pool({
      connectionString: process.env.DATABASE_URL,
    })
  ),
});

async function createAdmin() {
  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;
  const role = 'ADMIN';

  if (!email || !password) {
    console.error('❌ Set ADMIN_EMAIL and ADMIN_PASSWORD in the environment before running this script.');
    process.exit(1);
  }

  try {
    // Check if admin already exists
    const existingUser = await prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      if (existingUser.role === 'ADMIN') {
        console.log('✅ Admin user already exists with this email');
        return;
      } else {
        // Update existing user to admin
        const hashedPassword = await bcrypt.hash(password, 10);
        await prisma.user.update({
          where: { email },
          data: {
            role: 'ADMIN',
            password: hashedPassword,
          },
        });
        console.log('✅ Updated existing user to ADMIN role');
        return;
      }
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('🔐 Password hashed successfully');

    // Create admin user
    const admin = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        role: 'ADMIN',
      },
    });

    console.log('✅ Admin user created successfully!');
    console.log('📧 Email:', admin.email);
    console.log('🔑 Password:', password);
    console.log('👤 Role:', admin.role);
    console.log('🆔 ID:', admin.id);
    console.log('\n⚠️  IMPORTANT: Save this password securely!');
    console.log('⚠️  You can now login to the admin panel with:');
    console.log('   Email:', email);
    console.log('   Password:', password);
  } catch (error: any) {
    console.error('❌ Error creating admin user:', error.message);
    if (error.code === 'P2002') {
      console.error('   User with this email already exists');
    }
  } finally {
    await prisma.$disconnect();
  }
}

createAdmin();
