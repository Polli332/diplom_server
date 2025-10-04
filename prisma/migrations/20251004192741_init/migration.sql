/*
  Warnings:

  - Added the required column `role` to the `Applicant` table without a default value. This is not possible if the table is not empty.
  - Added the required column `role` to the `Manager` table without a default value. This is not possible if the table is not empty.
  - Added the required column `role` to the `Mechanic` table without a default value. This is not possible if the table is not empty.

*/
-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Applicant" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "photo" TEXT,
    "password" TEXT NOT NULL,
    "email" TEXT NOT NULL
);
INSERT INTO "new_Applicant" ("email", "id", "name", "password", "photo") SELECT "email", "id", "name", "password", "photo" FROM "Applicant";
DROP TABLE "Applicant";
ALTER TABLE "new_Applicant" RENAME TO "Applicant";
CREATE UNIQUE INDEX "Applicant_email_key" ON "Applicant"("email");
CREATE TABLE "new_Manager" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "photo" TEXT,
    "password" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "serviceId" INTEGER NOT NULL,
    CONSTRAINT "Manager_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_Manager" ("email", "id", "name", "password", "photo", "serviceId") SELECT "email", "id", "name", "password", "photo", "serviceId" FROM "Manager";
DROP TABLE "Manager";
ALTER TABLE "new_Manager" RENAME TO "Manager";
CREATE UNIQUE INDEX "Manager_email_key" ON "Manager"("email");
CREATE UNIQUE INDEX "Manager_serviceId_key" ON "Manager"("serviceId");
CREATE TABLE "new_Mechanic" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "photo" TEXT,
    "password" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "serviceId" INTEGER NOT NULL,
    CONSTRAINT "Mechanic_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_Mechanic" ("email", "id", "name", "password", "photo", "serviceId") SELECT "email", "id", "name", "password", "photo", "serviceId" FROM "Mechanic";
DROP TABLE "Mechanic";
ALTER TABLE "new_Mechanic" RENAME TO "Mechanic";
CREATE UNIQUE INDEX "Mechanic_email_key" ON "Mechanic"("email");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
