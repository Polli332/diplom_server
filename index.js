// index.js
import express from "express";
import { PrismaClient } from "@prisma/client";

const app = express();
const prisma = new PrismaClient();
const PORT = 3000;

app.use(express.json());

// ==================== ЗАЯВИТЕЛИ ====================
app.get("/applicants", async (req, res) => {
  const applicants = await prisma.applicant.findMany({ include: { requests: true } });
  res.json(applicants);
});

app.get("/applicants/:id", async (req, res) => {
  const { id } = req.params;
  const applicant = await prisma.applicant.findUnique({
    where: { id: Number(id) },
    include: { requests: true },
  });
  res.json(applicant);
});

app.post("/applicants", async (req, res) => {
  try {
    const { name, role, photo, password, email } = req.body;
    const applicant = await prisma.applicant.create({
      data: { name, role, photo, password, email },
    });
    res.json(applicant);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ЗАЯВКИ ====================
app.get("/requests", async (req, res) => {
  const requests = await prisma.request.findMany({
    include: { applicant: true, mechanic: true, transport: true, service: true },
  });
  res.json(requests);
});

app.get("/requests/:id", async (req, res) => {
  const { id } = req.params;
  const request = await prisma.request.findUnique({
    where: { id: Number(id) },
    include: { applicant: true, mechanic: true, transport: true, service: true },
  });
  res.json(request);
});

app.post("/requests", async (req, res) => {
  try {
    const { problem, transportId, applicantId, mechanicId, serviceId, closedAt } = req.body;
    const request = await prisma.request.create({
      data: { problem, transportId, applicantId, mechanicId, serviceId, closedAt },
    });
    res.json(request);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ТРАНСПОРТ ====================
app.get("/transports", async (req, res) => {
  const transports = await prisma.transport.findMany({ include: { requests: true } });
  res.json(transports);
});

app.post("/transports", async (req, res) => {
  try {
    const { type, serial, photo, model } = req.body;
    const transport = await prisma.transport.create({
      data: { type, serial, photo, model },
    });
    res.json(transport);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== МЕХАНИК ====================
app.get("/mechanics", async (req, res) => {
  const mechanics = await prisma.mechanic.findMany({
    include: { requests: true, service: true },
  });
  res.json(mechanics);
});

app.post("/mechanics", async (req, res) => {
  try {
    const { name, role, photo, password, email, serviceId } = req.body;
    const mechanic = await prisma.mechanic.create({
      data: { name, role, photo, password, email, serviceId },
    });
    res.json(mechanic);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== МЕНЕДЖЕР ====================
app.get("/managers", async (req, res) => {
  const managers = await prisma.manager.findMany({
    include: { service: true },
  });
  res.json(managers);
});

app.post("/managers", async (req, res) => {
  try {
    const { name, role, photo, password, email, serviceId } = req.body;
    const manager = await prisma.manager.create({
      data: { name, role, photo, password, email, serviceId },
    });
    res.json(manager);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== СЕРВИС ====================
app.get("/services", async (req, res) => {
  const services = await prisma.service.findMany({
    include: { manager: true, mechanics: true, requests: true },
  });
  res.json(services);
});

app.post("/services", async (req, res) => {
  try {
    const { address, workTime } = req.body;
    const service = await prisma.service.create({ data: { address, workTime } });
    res.json(service);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== СЕРВЕР ====================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});
