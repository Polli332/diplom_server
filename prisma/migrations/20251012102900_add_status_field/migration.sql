-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Request" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "problem" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'новая',
    "submittedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closedAt" DATETIME,
    "transportId" INTEGER NOT NULL,
    "applicantId" INTEGER NOT NULL,
    "mechanicId" INTEGER,
    "serviceId" INTEGER,
    CONSTRAINT "Request_transportId_fkey" FOREIGN KEY ("transportId") REFERENCES "Transport" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Request_applicantId_fkey" FOREIGN KEY ("applicantId") REFERENCES "Applicant" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Request_mechanicId_fkey" FOREIGN KEY ("mechanicId") REFERENCES "Mechanic" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "Request_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
INSERT INTO "new_Request" ("applicantId", "closedAt", "id", "mechanicId", "problem", "serviceId", "submittedAt", "transportId") SELECT "applicantId", "closedAt", "id", "mechanicId", "problem", "serviceId", "submittedAt", "transportId" FROM "Request";
DROP TABLE "Request";
ALTER TABLE "new_Request" RENAME TO "Request";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
