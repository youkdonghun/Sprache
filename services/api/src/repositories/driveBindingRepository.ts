import type { PrismaClient } from "@prisma/client";

export type DriveBinding = {
  accountKey: string;
  appRootFolderId: string;
  appRootFolderName: string | null;
  schemaVersion: number;
  createdAt: Date;
  updatedAt: Date;
};

export type UpsertDriveBinding = {
  accountKey: string;
  appRootFolderId: string;
  appRootFolderName: string | null;
  schemaVersion: number;
};

export interface DriveBindingRepository {
  findByAccountKey(accountKey: string): Promise<DriveBinding | null>;
  upsert(input: UpsertDriveBinding): Promise<DriveBinding>;
  deleteByAccountKey(accountKey: string): Promise<void>;
}

export class PrismaDriveBindingRepository implements DriveBindingRepository {
  constructor(private readonly prisma: PrismaClient) {}

  findByAccountKey(accountKey: string): Promise<DriveBinding | null> {
    return this.prisma.accountDriveBinding.findUnique({
      where: { accountKey },
    });
  }

  upsert(input: UpsertDriveBinding): Promise<DriveBinding> {
    return this.prisma.accountDriveBinding.upsert({
      where: { accountKey: input.accountKey },
      create: input,
      update: {
        appRootFolderId: input.appRootFolderId,
        appRootFolderName: input.appRootFolderName,
        schemaVersion: input.schemaVersion,
      },
    });
  }

  async deleteByAccountKey(accountKey: string): Promise<void> {
    await this.prisma.accountDriveBinding.deleteMany({
      where: { accountKey },
    });
  }
}

