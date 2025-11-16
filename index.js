import express from "express";
import cors from "cors"; 
import { PrismaClient } from "@prisma/client";

const app = express();
app.use(cors()); 
const prisma = new PrismaClient();
const PORT = 3000;

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

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

// ==================== ОБНОВЛЕНИЕ ЗАЯВИТЕЛЯ ====================
app.put("/applicants/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, photo, password } = req.body;
    
    const updateData = { name, email };
    
    if (photo !== undefined) {
      updateData.photo = photo;
    }
    
    if (password && password.trim() !== '') {
      updateData.password = password;
    }
    
    const applicant = await prisma.applicant.update({
      where: { id: Number(id) },
      data: updateData,
    });
    
    res.json(applicant);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ЗАЯВКИ ====================
app.get("/requests", async (req, res) => {
  try {
    const requests = await prisma.request.findMany({
      include: { 
        applicant: true, 
        mechanic: true, 
        transport: true, 
        service: true 
      },
    });
    console.log(`Returning ${requests.length} requests`);
    res.json(requests);
  } catch (error) {
    console.error('Error fetching requests:', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/requests/:id", async (req, res) => {
  const { id } = req.params;
  const request = await prisma.request.findUnique({
    where: { id: Number(id) },
    include: { 
      applicant: true, 
      mechanic: true, 
      transport: true, 
      service: true 
    },
  });
  res.json(request);
});

app.post("/requests", async (req, res) => {
  try {
    const { problem, transportId, applicantId, mechanicId, serviceId, closedAt, status } = req.body;
    
    console.log('Creating request with data:', {
      problem,
      transportId,
      applicantId,
      mechanicId,
      serviceId,
      closedAt,
      status
    });
    
    const request = await prisma.request.create({
      data: { 
        problem, 
        transportId: Number(transportId), 
        applicantId: Number(applicantId), 
        mechanicId: mechanicId ? Number(mechanicId) : null, 
        serviceId: serviceId ? Number(serviceId) : null, 
        closedAt,
        status: status || "новая"
      },
    });
    
    console.log('Request created successfully:', request);
    res.json(request);
  } catch (error) {
    console.error('Error creating request:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ОБНОВЛЕНИЕ ЗАЯВКИ ====================
app.put("/requests/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { problem, mechanicId, serviceId, closedAt, status } = req.body;
    
    console.log('🔄 Обновление заявки:', {
      id,
      problem,
      mechanicId,
      serviceId,
      closedAt,
      status
    });
    
    const updateData = {};
    
    if (problem !== undefined) updateData.problem = problem;
    if (mechanicId !== undefined) {
      updateData.mechanicId = mechanicId === null ? null : Number(mechanicId);
    }
    if (serviceId !== undefined) {
      updateData.serviceId = serviceId === null ? null : Number(serviceId);
    }
    
    // Обработка closedAt - преобразуем null в undefined для Prisma
    if (closedAt !== undefined) {
      if (closedAt === null) {
        updateData.closedAt = null;
      } else if (closedAt) {
        updateData.closedAt = new Date(closedAt);
      }
    }
    
    if (status !== undefined) updateData.status = status;
    
    console.log('📦 Данные для обновления:', updateData);
    
    const request = await prisma.request.update({
      where: { id: Number(id) },
      data: updateData,
      include: {
        applicant: true,
        mechanic: true,
        transport: true,
        service: true
      }
    });
    
    console.log('✅ Заявка успешно обновлена:', {
      id: request.id,
      status: request.status,
      closedAt: request.closedAt
    });
    
    res.json(request);
  } catch (error) {
    console.error('❌ Ошибка обновления заявки:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ОТКЛОНЕНИЕ ЗАЯВКИ ====================
app.put("/requests/:id/reject", async (req, res) => {
  try {
    const { id } = req.params;
    
    console.log('❌ Отклонение заявки:', id);
    
    const request = await prisma.request.update({
      where: { id: Number(id) },
      data: {
        status: "отклонена",
        closedAt: new Date()
      },
      include: {
        applicant: true,
        mechanic: true,
        transport: true,
        service: true
      }
    });
    
    console.log('✅ Заявка отклонена:', {
      id: request.id,
      status: request.status,
      closedAt: request.closedAt
    });
    
    res.json(request);
  } catch (error) {
    console.error('❌ Ошибка отклонения заявки:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ОБНОВЛЕНИЕ СТАТУСА ЗАЯВКИ ====================
app.put("/requests/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    console.log('🔄 Обновление статуса заявки:', { id, status });
    
    const updateData = { status };
    
    // Автоматически управляем closedAt в зависимости от статуса
    if (status === 'отклонена') {
      updateData.closedAt = new Date();
    } else if (status === 'новая') {
      updateData.closedAt = null;
    }
    
    const request = await prisma.request.update({
      where: { id: Number(id) },
      data: updateData,
      include: {
        applicant: true,
        mechanic: true,
        transport: true,
        service: true
      }
    });
    
    console.log('✅ Статус заявки обновлен:', {
      id: request.id,
      status: request.status,
      closedAt: request.closedAt
    });
    
    res.json(request);
  } catch (error) {
    console.error('❌ Ошибка обновления статуса заявки:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ТРАНСПОРТ ====================
app.get("/transports", async (req, res) => {
  try {
    const transports = await prisma.transport.findMany({ 
      include: { requests: true } 
    });
    console.log(`Returning ${transports.length} transports`);
    res.json(transports);
  } catch (error) {
    console.error('Error fetching transports:', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/transports/:id", async (req, res) => {
  const { id } = req.params;
  const transport = await prisma.transport.findUnique({
    where: { id: Number(id) },
    include: { requests: true },
  });
  res.json(transport);
});

app.post("/transports", async (req, res) => {
  try {
    const { type, serial, photo, model } = req.body;
    
    console.log('Creating transport with data:', {
      type, serial, model, photo: photo ? 'photo provided' : 'no photo'
    });
    
    const transport = await prisma.transport.create({
      data: { type, serial, photo, model },
    });
    
    console.log('Transport created successfully:', transport);
    res.json(transport);
  } catch (error) {
    console.error('Error creating transport:', error);
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

app.get("/mechanics/:id", async (req, res) => {
  const { id } = req.params;
  const mechanic = await prisma.mechanic.findUnique({
    where: { id: Number(id) },
    include: { requests: true, service: true },
  });
  res.json(mechanic);
});

app.post("/mechanics", async (req, res) => {
  try {
    const { name, role, photo, password, email, serviceId } = req.body;
    console.log('Creating mechanic with data:', {
      name, email, serviceId, photo: photo ? 'photo provided' : 'no photo'
    });
    
    const mechanic = await prisma.mechanic.create({
      data: { 
        name, 
        role: role || "mechanic", 
        photo, 
        password, 
        email, 
        serviceId: serviceId ? Number(serviceId) : null
      },
    });
    
    console.log('Mechanic created successfully:', mechanic);
    res.json(mechanic);
  } catch (error) {
    console.error('Error creating mechanic:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ОБНОВЛЕНИЕ МЕХАНИКА ====================
app.put("/mechanics/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, photo, password } = req.body;
    
    console.log('Updating mechanic:', { id, name, email, photo: photo ? 'photo provided' : 'no photo' });
    
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (email !== undefined) updateData.email = email;
    
    if (photo !== undefined) {
      updateData.photo = photo;
    }
    
    if (password && password.trim() !== '') {
      updateData.password = password;
    }
    
    const mechanic = await prisma.mechanic.update({
      where: { id: Number(id) },
      data: updateData,
    });
    
    console.log('Mechanic updated successfully:', mechanic);
    res.json(mechanic);
  } catch (error) {
    console.error('Error updating mechanic:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== УДАЛЕНИЕ МЕХАНИКА ====================
app.delete("/mechanics/:id", async (req, res) => {
  try {
    const { id } = req.params;
    
    await prisma.request.updateMany({
      where: { mechanicId: Number(id) },
      data: { mechanicId: null },
    });
    
    await prisma.mechanic.delete({
      where: { id: Number(id) },
    });
    
    res.json({ message: "Mechanic deleted successfully" });
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

app.get("/managers/:id", async (req, res) => {
  const { id } = req.params;
  const manager = await prisma.manager.findUnique({
    where: { id: Number(id) },
    include: { service: true },
  });
  res.json(manager);
});

app.post("/managers", async (req, res) => {
  try {
    const { name, role, photo, password, email, serviceId } = req.body;
    const manager = await prisma.manager.create({
      data: { 
        name, 
        role: role || "manager", 
        photo, 
        password, 
        email, 
        serviceId 
      },
    });
    res.json(manager);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ОБНОВЛЕНИЕ МЕНЕДЖЕРА ====================
app.put("/managers/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, photo, password } = req.body;
    
    console.log('Updating manager:', { id, name, email, photo: photo ? 'photo provided' : 'no photo' });
    
    const updateData = { name, email };
    
    if (photo !== undefined) {
      updateData.photo = photo;
    }
    
    if (password && password.trim() !== '') {
      updateData.password = password;
    }
    
    const manager = await prisma.manager.update({
      where: { id: Number(id) },
      data: updateData,
    });
    
    console.log('Manager updated successfully:', manager);
    res.json(manager);
  } catch (error) {
    console.error('Error updating manager:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== СЕРВИС ====================
app.get("/services", async (req, res) => {
  try {
    const services = await prisma.service.findMany({
      select: {
        id: true,
        address: true,
        workTime: true,
        manager: {
          select: {
            id: true,
            name: true
          }
        },
        mechanics: {
          select: {
            id: true,
            name: true
          }
        }
      }
    });
    
    console.log(`Returning ${services.length} services`);
    res.json(services);
  } catch (error) {
    console.error('Error fetching services:', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/services/:id", async (req, res) => {
  const { id } = req.params;
  const service = await prisma.service.findUnique({
    where: { id: Number(id) },
    include: { 
      manager: true, 
      mechanics: true, 
      requests: true 
    },
  });
  res.json(service);
});

app.post("/services", async (req, res) => {
  try {
    const { address, workTime } = req.body;
    const service = await prisma.service.create({ 
      data: { address, workTime } 
    });
    res.json(service);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ДОПОЛНИТЕЛЬНЫЕ ENDPOINT'Ы ====================

app.get("/services-with-details", async (req, res) => {
  try {
    const services = await prisma.service.findMany({
      include: { 
        manager: true,
        mechanics: true 
      },
    });
    res.json(services);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.get("/services/available", async (req, res) => {
  try {
    const services = await prisma.service.findMany({
      select: {
        id: true,
        address: true,
        workTime: true,
        manager: {
          select: {
            id: true,
            name: true
          }
        },
        mechanics: {
          select: {
            id: true,
            name: true
          }
        }
      },
      where: {
        manager: { isNot: null },
        mechanics: { some: {} }
      }
    });
    
    console.log(`Returning ${services.length} available services`);
    res.json(services);
  } catch (error) {
    console.error('Error fetching available services:', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/services/debug", async (req, res) => {
  try {
    const allServices = await prisma.service.findMany();
    const servicesWithDetails = await prisma.service.findMany({
      include: { 
        manager: true,
        mechanics: true 
      }
    });
    
    res.json({
      allServicesCount: allServices.length,
      servicesWithDetailsCount: servicesWithDetails.length,
      allServices: allServices,
      servicesWithDetails: servicesWithDetails
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ПРОВЕРКА БАЗЫ ДАННЫХ ====================
app.get("/debug/database", async (req, res) => {
  try {
    const servicesCount = await prisma.service.count();
    const transportsCount = await prisma.transport.count();
    const requestsCount = await prisma.request.count();
    const applicantsCount = await prisma.applicant.count();
    const mechanicsCount = await prisma.mechanic.count();
    const managersCount = await prisma.manager.count();
    
    const recentRequests = await prisma.request.findMany({
      take: 5,
      orderBy: { id: 'desc' },
      include: { transport: true, service: true, applicant: true, mechanic: true }
    });
    
    res.json({
      counts: {
        services: servicesCount,
        transports: transportsCount,
        requests: requestsCount,
        applicants: applicantsCount,
        mechanics: mechanicsCount,
        managers: managersCount
      },
      recentRequests: recentRequests
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ТЕСТОВАЯ ЗАЯВКА ====================
app.post("/test/request", async (req, res) => {
  try {
    const { applicantId } = req.body;
    
    const transport = await prisma.transport.create({
      data: {
        type: "троллейбусы",
        serial: `TEST-${Date.now()}`,
        model: "Тестовая модель",
        photo: null
      }
    });
    
    const request = await prisma.request.create({
      data: {
        problem: "Тестовая проблема",
        transportId: transport.id,
        applicantId: applicantId,
        status: "новая",
        submittedAt: new Date()
      }
    });
    
    res.json({
      success: true,
      request: request,
      transport: transport
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ПРОВЕРКА ФОТО ====================
app.post("/test/photo", async (req, res) => {
  try {
    const { photo, testName } = req.body;
    console.log(`Тест фото ${testName}:`, {
      hasPhoto: !!photo,
      photoLength: photo ? photo.length : 0,
      first100Chars: photo ? photo.substring(0, 100) : 'none'
    });
    
    res.json({
      success: true,
      message: `Тест фото ${testName} получен`,
      photoInfo: {
        received: !!photo,
        length: photo ? photo.length : 0
      }
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ==================== ОБЩИЙ ENDPOINT ДЛЯ ОБНОВЛЕНИЯ ФОТО ====================
app.put("/update-photo/:type/:id", async (req, res) => {
  try {
    const { type, id } = req.params;
    const { photo } = req.body;
    
    console.log(`Updating photo for ${type} id ${id}:`, {
      photoLength: photo ? photo.length : 0
    });
    
    let result;
    
    switch (type) {
      case 'manager':
        result = await prisma.manager.update({
          where: { id: Number(id) },
          data: { photo },
        });
        break;
      case 'mechanic':
        result = await prisma.mechanic.update({
          where: { id: Number(id) },
          data: { photo },
        });
        break;
      case 'applicant':
        result = await prisma.applicant.update({
          where: { id: Number(id) },
          data: { photo },
        });
        break;
      default:
        return res.status(400).json({ error: 'Invalid type' });
    }
    
    res.json(result);
  } catch (error) {
    console.error(`Error updating photo for ${type}:`, error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ПОЛУЧЕНИЕ ДАННЫХ ПОЛЬЗОВАТЕЛЯ С ФОТО ====================
app.get("/user-data/:type/:id", async (req, res) => {
  try {
    const { type, id } = req.params;
    
    let user;
    switch (type) {
      case 'manager':
        user = await prisma.manager.findUnique({
          where: { id: Number(id) },
          select: { id: true, name: true, email: true, photo: true, serviceId: true }
        });
        break;
      case 'mechanic':
        user = await prisma.mechanic.findUnique({
          where: { id: Number(id) },
          select: { id: true, name: true, email: true, photo: true, serviceId: true }
        });
        break;
      case 'applicant':
        user = await prisma.applicant.findUnique({
          where: { id: Number(id) },
          select: { id: true, name: true, email: true, photo: true }
        });
        break;
      default:
        return res.status(400).json({ error: 'Invalid type' });
    }
    
    if (user) {
      res.json(user);
    } else {
      res.status(404).json({ error: 'User not found' });
    }
  } catch (error) {
    console.error(`Error fetching user data for ${type}:`, error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ЭНДПОИНТЫ ДЛЯ МЕХАНИКА ====================

// Получение заявок механика
app.get("/mechanic/requests/:mechanicId", async (req, res) => {
  try {
    const { mechanicId } = req.params;
    
    const requests = await prisma.request.findMany({
      where: { 
        mechanicId: Number(mechanicId),
        status: { not: "завершена" }
      },
      include: { 
        applicant: true, 
        mechanic: true, 
        transport: true, 
        service: true 
      },
      orderBy: { submittedAt: 'desc' }
    });
    
    console.log(`Returning ${requests.length} requests for mechanic ${mechanicId}`);
    res.json(requests);
  } catch (error) {
    console.error('Error fetching mechanic requests:', error);
    res.status(400).json({ error: error.message });
  }
});

// Завершение заявки
app.put("/mechanic/requests/:id/complete", async (req, res) => {
  try {
    const { id } = req.params;
    
    const request = await prisma.request.update({
      where: { id: Number(id) },
      data: {
        status: "завершена",
        closedAt: new Date()
      },
      include: {
        applicant: true,
        mechanic: true,
        transport: true,
        service: true
      }
    });
    
    console.log(`Request ${id} completed by mechanic`);
    res.json(request);
  } catch (error) {
    console.error('Error completing request:', error);
    res.status(400).json({ error: error.message });
  }
});

// Обновление статуса заявки механиком
app.put("/mechanic/requests/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    const request = await prisma.request.update({
      where: { id: Number(id) },
      data: { status },
      include: {
        applicant: true,
        mechanic: true,
        transport: true,
        service: true
      }
    });
    
    console.log(`Request ${id} status updated to: ${status}`);
    res.json(request);
  } catch (error) {
    console.error('Error updating request status:', error);
    res.status(400).json({ error: error.message });
  }
});

// Получение данных механика с фото
app.get("/mechanic/:id", async (req, res) => {
  try {
    const { id } = req.params;
    
    const mechanic = await prisma.mechanic.findUnique({
      where: { id: Number(id) },
      select: { 
        id: true, 
        name: true, 
        email: true, 
        photo: true, 
        serviceId: true 
      }
    });
    
    if (mechanic) {
      res.json(mechanic);
    } else {
      res.status(404).json({ error: 'Mechanic not found' });
    }
  } catch (error) {
    console.error('Error fetching mechanic data:', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== СЕРВЕР ====================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});