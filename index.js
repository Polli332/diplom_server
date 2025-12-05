import express from "express";
import cors from "cors"; 
import { PrismaClient } from "@prisma/client";

const app = express();
app.use(cors()); 
const prisma = new PrismaClient();
const PORT = 3000;

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// ==================== ЛОГИРОВАНИЕ ====================
const logger = {
  info: (message, data = {}) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ℹ️ INFO: ${message}`, Object.keys(data).length ? data : '');
  },
  
  error: (message, error = {}) => {
    const timestamp = new Date().toISOString();
    console.error(`[${timestamp}] ❌ ERROR: ${message}`, error.message ? error : '');
  },
  
  warn: (message, data = {}) => {
    const timestamp = new Date().toISOString();
    console.warn(`[${timestamp}] ⚠️ WARN: ${message}`, Object.keys(data).length ? data : '');
  },
  
  debug: (message, data = {}) => {
    const timestamp = new Date().toISOString();
    console.debug(`[${timestamp}] 🔍 DEBUG: ${message}`, Object.keys(data).length ? data : '');
  },
  
  success: (message, data = {}) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ✅ SUCCESS: ${message}`, Object.keys(data).length ? data : '');
  },
  
  request: (method, url, ip, userAgent) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] 📞 REQUEST: ${method} ${url} from ${ip} (${userAgent})`);
  },
  
  response: (method, url, statusCode, responseTime) => {
    const timestamp = new Date().toISOString();
    const statusEmoji = statusCode >= 200 && statusCode < 300 ? '✅' : 
                       statusCode >= 400 && statusCode < 500 ? '⚠️' : '❌';
    console.log(`[${timestamp}] ${statusEmoji} RESPONSE: ${method} ${url} - ${statusCode} (${responseTime}ms)`);
  }
};

// Middleware для логирования всех запросов
app.use((req, res, next) => {
  const startTime = Date.now();
  const ip = req.ip || req.connection.remoteAddress;
  const userAgent = req.get('User-Agent') || 'Unknown';
  
  logger.request(req.method, req.url, ip, userAgent);
  
  // Логируем тело запроса для POST/PUT запросов (кроме паролей)
  if (['POST', 'PUT'].includes(req.method) && req.body) {
    const logBody = { ...req.body };
    
    // Скрываем пароли в логах
    if (logBody.password) {
      logBody.password = '***HIDDEN***';
    }
    
    logger.debug(`Request body:`, logBody);
  }
  
  // Перехватываем отправку ответа для логирования
  const originalSend = res.send;
  res.send = function(body) {
    const responseTime = Date.now() - startTime;
    logger.response(req.method, req.url, res.statusCode, responseTime);
    
    // Логируем тело ответа для ошибок
    if (res.statusCode >= 400 && typeof body === 'string') {
      try {
        const parsedBody = JSON.parse(body);
        logger.debug(`Error response:`, parsedBody);
      } catch (e) {
        logger.debug(`Error response (raw): ${body.substring(0, 200)}...`);
      }
    }
    
    return originalSend.call(this, body);
  };
  
  next();
});

// ==================== АВТОРИЗАЦИЯ ====================
app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    
    logger.info('Попытка входа', { email });
    
    let user = null;
    let role = null;
    
    // 1. Поиск в заявителях
    logger.debug('Поиск пользователя в таблице заявителей');
    user = await prisma.applicant.findFirst({
      where: { 
        email: email,
        password: password 
      }
    });
    if (user) {
      role = 'applicant';
      logger.debug('Пользователь найден как заявитель', { id: user.id });
    }
    
    // 2. Поиск в механиках
    if (!user) {
      logger.debug('Поиск пользователя в таблице механиков');
      user = await prisma.mechanic.findFirst({
        where: { 
          email: email,
          password: password 
        }
      });
      if (user) {
        role = 'mechanic';
        logger.debug('Пользователь найден как механик', { id: user.id });
      }
    }
    
    // 3. Поиск в менеджерах
    if (!user) {
      logger.debug('Поиск пользователя в таблице менеджеров');
      user = await prisma.manager.findFirst({
        where: { 
          email: email,
          password: password 
        }
      });
      if (user) {
        role = 'manager';
        logger.debug('Пользователь найден как менеджер', { id: user.id });
      }
    }
    
    if (!user) {
      logger.warn('Неудачная попытка входа', { email, reason: 'Неверный email или пароль' });
      return res.status(401).json({ error: 'Неверный email или пароль' });
    }
    
    logger.success('Успешный вход', { id: user.id, name: user.name, role });
    
    res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      photo: user.photo,
      role: role,
      serviceId: user.serviceId
    });
    
  } catch (error) {
    logger.error('Ошибка входа', error);
    res.status(400).json({ error: error.message });
  }
});

app.post("/auth/register", async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    
    logger.info('Регистрация пользователя', { name, email, role });
    
    logger.debug('Проверка существующего пользователя');
    const existingUser = await prisma.applicant.findFirst({
      where: { email: email }
    });
    
    if (existingUser) {
      logger.warn('Попытка регистрации существующего email', { email });
      return res.status(400).json({ error: 'Пользователь с таким email уже существует' });
    }
    
    logger.debug('Создание нового заявителя');
    const applicant = await prisma.applicant.create({
      data: { 
        name, 
        email, 
        password,
        role: role || 'applicant',
        photo: null
      },
    });
    
    logger.success('Успешная регистрация', { id: applicant.id, name: applicant.name });
    
    res.json({
      id: applicant.id,
      name: applicant.name,
      email: applicant.email,
      photo: applicant.photo,
      role: 'applicant',
      serviceId: null
    });
    
  } catch (error) {
    logger.error('Ошибка регистрации', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ЗАЯВИТЕЛИ ====================
app.get("/applicants", async (req, res) => {
  try {
    logger.info('Получение списка заявителей');
    
    const applicants = await prisma.applicant.findMany({ 
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true
      }
    });
    
    logger.success('Список заявителей получен', { count: applicants.length });
    res.json(applicants);
  } catch (error) {
    logger.error('Ошибка получения списка заявителей', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/applicants/:id", async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Получение данных заявителя', { id });
    
    const applicant = await prisma.applicant.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true
      }
    });
    
    if (applicant) {
      logger.success('Данные заявителя получены', { id: applicant.id, name: applicant.name });
      res.json(applicant);
    } else {
      logger.warn('Заявитель не найден', { id });
      res.status(404).json({ error: 'Заявитель не найден' });
    }
  } catch (error) {
    logger.error('Ошибка получения данных заявителя', error);
    res.status(400).json({ error: error.message });
  }
});

app.post("/applicants", async (req, res) => {
  try {
    const { name, role, photo, password, email } = req.body;
    
    logger.info('Создание нового заявителя', { name, email });
    
    const applicant = await prisma.applicant.create({
      data: { name, role, photo, password, email },
    });
    
    logger.success('Заявитель создан', { id: applicant.id });
    res.json(applicant);
  } catch (error) {
    logger.error('Ошибка создания заявителя', error);
    res.status(400).json({ error: error.message });
  }
});

app.put("/applicants/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, photo, password } = req.body;
    
    logger.info('Обновление данных заявителя', { id, name, email });
    
    const updateData = { name, email };
    
    if (photo !== undefined) {
      updateData.photo = photo;
    }
    
    if (password && password.trim() !== '') {
      updateData.password = password;
    }
    
    const applicant = await prisma.applicant.update({
      where: { id: parseInt(id) },
      data: updateData,
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true
      }
    });
    
    logger.success('Данные заявителя обновлены', { id: applicant.id });
    res.json(applicant);
  } catch (error) {
    logger.error('Ошибка обновления данных заявителя', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ЗАЯВКИ ====================
app.get("/requests", async (req, res) => {
  try {
    logger.info('Получение списка заявок');
    
    const requests = await prisma.request.findMany({
      include: { 
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        transport: true, 
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        } 
      },
      orderBy: { submittedAt: 'desc' }
    });
    
    logger.success('Список заявок получен', { count: requests.length });
    res.json(requests);
  } catch (error) {
    logger.error('Ошибка получения списка заявок', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/requests/:id", async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Получение данных заявки', { id });
    
    const request = await prisma.request.findUnique({
      where: { id: parseInt(id) },
      include: { 
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        transport: true, 
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        } 
      },
    });
    
    if (request) {
      logger.success('Данные заявки получены', { 
        id: request.id, 
        status: request.status,
        applicantId: request.applicantId 
      });
      res.json(request);
    } else {
      logger.warn('Заявка не найдена', { id });
      res.status(404).json({ error: 'Заявка не найдена' });
    }
  } catch (error) {
    logger.error('Ошибка получения данных заявки', error);
    res.status(400).json({ error: error.message });
  }
});

app.post("/requests", async (req, res) => {
  try {
    const { problem, transportId, applicantId, mechanicId, serviceId, closedAt, status } = req.body;
    
    logger.info('Создание новой заявки', {
      problem: problem?.substring(0, 50) + (problem?.length > 50 ? '...' : ''),
      transportId,
      applicantId,
      mechanicId,
      serviceId,
      status
    });
    
    const request = await prisma.request.create({
      data: { 
        problem, 
        transportId: parseInt(transportId), 
        applicantId: parseInt(applicantId), 
        mechanicId: mechanicId ? parseInt(mechanicId) : null, 
        serviceId: serviceId ? parseInt(serviceId) : null, 
        closedAt: closedAt ? new Date(closedAt) : null,
        status: status || "новая",
        submittedAt: new Date()
      },
    });
    
    logger.success('Заявка создана', { 
      id: request.id, 
      status: request.status,
      submittedAt: request.submittedAt 
    });
    
    const fullRequest = await prisma.request.findUnique({
      where: { id: request.id },
      include: { 
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        transport: true, 
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        } 
      },
    });
    
    res.json(fullRequest);
  } catch (error) {
    logger.error('Ошибка создания заявки', error);
    res.status(400).json({ error: error.message });
  }
});

app.put("/requests/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { problem, mechanicId, serviceId, closedAt, status } = req.body;
    
    logger.info('Обновление заявки', {
      id,
      problem: problem?.substring(0, 50) + (problem?.length > 50 ? '...' : ''),
      mechanicId,
      serviceId,
      closedAt,
      status
    });
    
    const updateData = {};
    
    if (problem !== undefined) updateData.problem = problem;
    if (mechanicId !== undefined) {
      updateData.mechanicId = mechanicId === null ? null : parseInt(mechanicId);
    }
    if (serviceId !== undefined) {
      updateData.serviceId = serviceId === null ? null : parseInt(serviceId);
    }
    
    if (closedAt !== undefined) {
      if (closedAt === null) {
        updateData.closedAt = null;
      } else if (closedAt) {
        updateData.closedAt = new Date(closedAt);
      }
    }
    
    if (status !== undefined) updateData.status = status;
    
    logger.debug('Данные для обновления заявки', updateData);
    
    const request = await prisma.request.update({
      where: { id: parseInt(id) },
      data: updateData,
      include: {
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        transport: true,
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        }
      }
    });
    
    logger.success('Заявка обновлена', {
      id: request.id,
      status: request.status,
      closedAt: request.closedAt
    });
    
    res.json(request);
  } catch (error) {
    logger.error('Ошибка обновления заявки', error);
    res.status(400).json({ error: error.message });
  }
});

app.put("/requests/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    logger.info('Обновление статуса заявки', { id, status });
    
    const updateData = { status };
    
    if (status === 'отклонена' || status === 'завершена') {
      updateData.closedAt = new Date();
    } else if (status === 'новая') {
      updateData.closedAt = null;
    }
    
    const request = await prisma.request.update({
      where: { id: parseInt(id) },
      data: updateData,
      include: {
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        transport: true,
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        }
      }
    });
    
    logger.success('Статус заявки обновлен', {
      id: request.id,
      status: request.status,
      closedAt: request.closedAt
    });
    
    res.json(request);
  } catch (error) {
    logger.error('Ошибка обновления статуса заявки', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ТРАНСПОРТ ====================
app.get("/transports", async (req, res) => {
  try {
    logger.info('Получение списка транспорта');
    
    const transports = await prisma.transport.findMany({ 
      select: {
        id: true,
        type: true,
        serial: true,
        model: true,
        photo: true
      }
    });
    
    logger.success('Список транспорта получен', { count: transports.length });
    res.json(transports);
  } catch (error) {
    logger.error('Ошибка получения списка транспорта', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/transports/:id", async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Получение данных транспорта', { id });
    
    const transport = await prisma.transport.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        type: true,
        serial: true,
        model: true,
        photo: true
      }
    });
    
    if (transport) {
      logger.success('Данные транспорта получены', { 
        id: transport.id, 
        type: transport.type,
        model: transport.model 
      });
      res.json(transport);
    } else {
      logger.warn('Транспорт не найден', { id });
      res.status(404).json({ error: 'Транспорт не найден' });
    }
  } catch (error) {
    logger.error('Ошибка получения данных транспорта', error);
    res.status(400).json({ error: error.message });
  }
});

app.post("/transports", async (req, res) => {
  try {
    const { type, serial, photo, model } = req.body;
    
    logger.info('Создание нового транспорта', {
      type, 
      serial, 
      model, 
      hasPhoto: !!photo
    });
    
    const transport = await prisma.transport.create({
      data: { 
        type, 
        serial, 
        photo, 
        model 
      },
    });
    
    logger.success('Транспорт создан', { 
      id: transport.id,
      type: transport.type,
      model: transport.model 
    });
    
    res.json({
      id: transport.id,
      type: transport.type,
      serial: transport.serial,
      model: transport.model,
      photo: transport.photo
    });
  } catch (error) {
    logger.error('Ошибка создания транспорта', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== МЕХАНИК ====================
app.get("/mechanics", async (req, res) => {
  try {
    logger.info('Получение списка механиков');
    
    const mechanics = await prisma.mechanic.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true,
        serviceId: true
      }
    });
    
    logger.success('Список механиков получен', { count: mechanics.length });
    res.json(mechanics);
  } catch (error) {
    logger.error('Ошибка получения списка механиков', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/mechanics/:id", async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Получение данных механика', { id });
    
    const mechanic = await prisma.mechanic.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true,
        serviceId: true
      }
    });
    
    if (mechanic) {
      logger.success('Данные механика получены', { 
        id: mechanic.id, 
        name: mechanic.name,
        serviceId: mechanic.serviceId 
      });
      res.json(mechanic);
    } else {
      logger.warn('Механик не найден', { id });
      res.status(404).json({ error: 'Механик не найден' });
    }
  } catch (error) {
    logger.error('Ошибка получения данных механика', error);
    res.status(400).json({ error: error.message });
  }
});

app.post("/mechanics", async (req, res) => {
  try {
    const { name, role, photo, password, email, serviceId } = req.body;
    
    logger.info('Создание нового механика', {
      name, 
      email, 
      serviceId, 
      hasPhoto: !!photo
    });
    
    const mechanic = await prisma.mechanic.create({
      data: { 
        name, 
        role: role || "mechanic", 
        photo, 
        password, 
        email, 
        serviceId: serviceId ? parseInt(serviceId) : null
      },
    });
    
    logger.success('Механик создан', { 
      id: mechanic.id,
      name: mechanic.name,
      serviceId: mechanic.serviceId 
    });
    
    res.json({
      id: mechanic.id,
      name: mechanic.name,
      email: mechanic.email,
      photo: mechanic.photo,
      role: mechanic.role,
      serviceId: mechanic.serviceId
    });
  } catch (error) {
    logger.error('Ошибка создания механика', error);
    res.status(400).json({ error: error.message });
  }
});

app.put("/mechanics/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, photo, password, serviceId } = req.body;
    
    logger.info('Обновление данных механика', { 
      id, 
      name, 
      email, 
      serviceId,
      hasPhoto: !!photo 
    });
    
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (email !== undefined) updateData.email = email;
    if (serviceId !== undefined) {
      updateData.serviceId = serviceId === null ? null : parseInt(serviceId);
    }
    
    if (photo !== undefined) {
      updateData.photo = photo;
    }
    
    if (password && password.trim() !== '') {
      updateData.password = password;
    }
    
    const mechanic = await prisma.mechanic.update({
      where: { id: parseInt(id) },
      data: updateData,
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true,
        serviceId: true
      }
    });
    
    logger.success('Данные механика обновлены', { 
      id: mechanic.id,
      name: mechanic.name 
    });
    
    res.json(mechanic);
  } catch (error) {
    logger.error('Ошибка обновления данных механика', error);
    res.status(400).json({ error: error.message });
  }
});

app.delete("/mechanics/:id", async (req, res) => {
  try {
    const { id } = req.params;
    
    logger.info('Удаление механика', { id });
    
    logger.debug('Обновление связанных заявок (обнуление mechanicId)');
    await prisma.request.updateMany({
      where: { mechanicId: parseInt(id) },
      data: { mechanicId: null },
    });
    
    logger.debug('Удаление механика из базы данных');
    await prisma.mechanic.delete({
      where: { id: parseInt(id) },
    });
    
    logger.success('Механик удален', { id });
    
    res.json({ message: "Механик успешно удален" });
  } catch (error) {
    logger.error('Ошибка удаления механика', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== МЕНЕДЖЕР ====================
app.get("/managers", async (req, res) => {
  try {
    logger.info('Получение списка менеджеров');
    
    const managers = await prisma.manager.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true,
        serviceId: true
      }
    });
    
    logger.success('Список менеджеров получен', { count: managers.length });
    res.json(managers);
  } catch (error) {
    logger.error('Ошибка получения списка менеджеров', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/managers/:id", async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Получение данных менеджера', { id });
    
    const manager = await prisma.manager.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true,
        serviceId: true
      }
    });
    
    if (manager) {
      logger.success('Данные менеджера получены', { 
        id: manager.id, 
        name: manager.name,
        serviceId: manager.serviceId 
      });
      res.json(manager);
    } else {
      logger.warn('Менеджер не найден', { id });
      res.status(404).json({ error: 'Менеджер не найден' });
    }
  } catch (error) {
    logger.error('Ошибка получения данных менеджера', error);
    res.status(400).json({ error: error.message });
  }
});

app.post("/managers", async (req, res) => {
  try {
    const { name, role, photo, password, email, serviceId } = req.body;
    
    logger.info('Создание нового менеджера', {
      name, 
      email, 
      serviceId, 
      hasPhoto: !!photo
    });
    
    logger.debug('Проверка существующего email');
    const existingUser = await prisma.manager.findUnique({
      where: { email }
    });
    
    if (existingUser) {
      logger.warn('Попытка создания менеджера с существующим email', { email });
      return res.status(400).json({ error: 'Email уже используется' });
    }
    
    const manager = await prisma.manager.create({
      data: { 
        name, 
        role: role || "manager", 
        photo, 
        password, 
        email, 
        serviceId: serviceId ? parseInt(serviceId) : null
      },
    });
    
    logger.success('Менеджер создан', { 
      id: manager.id,
      name: manager.name,
      serviceId: manager.serviceId 
    });
    
    res.json({
      id: manager.id,
      name: manager.name,
      email: manager.email,
      photo: manager.photo,
      role: manager.role,
      serviceId: manager.serviceId
    });
  } catch (error) {
    logger.error('Ошибка создания менеджера', error);
    res.status(400).json({ error: error.message });
  }
});

app.put("/managers/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, photo, password, serviceId } = req.body;
    
    logger.info('Обновление данных менеджера', { 
      id, 
      name, 
      email, 
      serviceId,
      hasPhoto: !!photo 
    });
    
    const updateData = { name, email };
    
    if (serviceId !== undefined) {
      updateData.serviceId = serviceId === null ? null : parseInt(serviceId);
    }
    
    if (photo !== undefined) {
      updateData.photo = photo;
    }
    
    if (password && password.trim() !== '') {
      updateData.password = password;
    }
    
    const manager = await prisma.manager.update({
      where: { id: parseInt(id) },
      data: updateData,
      select: {
        id: true,
        name: true,
        email: true,
        photo: true,
        role: true,
        serviceId: true
      }
    });
    
    logger.success('Данные менеджера обновлены', { 
      id: manager.id,
      name: manager.name 
    });
    
    res.json(manager);
  } catch (error) {
    logger.error('Ошибка обновления данных менеджера', error);
    res.status(400).json({ error: error.message });
  }
});

app.delete("/managers/:id", async (req, res) => {
  try {
    const { id } = req.params;
    
    logger.info('Удаление менеджера', { id });
    
    const manager = await prisma.manager.delete({
      where: { id: parseInt(id) },
    });
    
    logger.success('Менеджер удален', { id });
    
    res.json(manager);
  } catch (error) {
    logger.error('Ошибка удаления менеджера', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== СЕРВИС ====================
app.get("/services", async (req, res) => {
  try {
    logger.info('Получение списка сервисов');
    
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
    
    logger.success('Список сервисов получен', { count: services.length });
    res.json(services);
  } catch (error) {
    logger.error('Ошибка получения списка сервисов', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/services/:id", async (req, res) => {
  try {
    const { id } = req.params;
    logger.info('Получение данных сервиса', { id });
    
    const service = await prisma.service.findUnique({
      where: { id: parseInt(id) },
      include: { 
        manager: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        mechanics: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      },
    });
    
    if (service) {
      logger.success('Данные сервиса получены', { 
        id: service.id, 
        address: service.address,
        managerId: service.manager?.id 
      });
      res.json(service);
    } else {
      logger.warn('Сервис не найден', { id });
      res.status(404).json({ error: 'Сервис не найден' });
    }
  } catch (error) {
    logger.error('Ошибка получения данных сервиса', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/services/:id/address", async (req, res) => {
  try {
    const { id } = req.params;
    
    logger.info('Получение адреса сервиса', { id });
    
    const service = await prisma.service.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        address: true
      }
    });
    
    if (service) {
      logger.success('Адрес сервиса получен', { 
        id: service.id, 
        address: service.address 
      });
      res.json({ address: service.address });
    } else {
      logger.warn('Сервис не найден при получении адреса', { id });
      res.status(404).json({ error: 'Сервис не найден' });
    }
  } catch (error) {
    logger.error('Ошибка получения адреса сервиса', error);
    res.status(400).json({ error: error.message });
  }
});

app.post("/services", async (req, res) => {
  try {
    const { address, workTime } = req.body;
    
    logger.info('Создание нового сервиса', { address, workTime });
    
    const service = await prisma.service.create({ 
      data: { 
        address, 
        workTime: workTime || '' 
      } 
    });
    
    logger.success('Сервис создан', { 
      id: service.id, 
      address: service.address 
    });
    
    res.json({
      id: service.id,
      address: service.address,
      workTime: service.workTime
    });
  } catch (error) {
    logger.error('Ошибка создания сервиса', error);
    res.status(400).json({ error: error.message });
  }
});

app.put("/services/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { address, workTime } = req.body;
    
    logger.info('Обновление данных сервиса', { id, address, workTime });
    
    const service = await prisma.service.update({
      where: { id: parseInt(id) },
      data: { 
        address, 
        workTime: workTime || '' 
      },
    });
    
    logger.success('Данные сервиса обновлены', { 
      id: service.id, 
      address: service.address 
    });
    
    res.json({
      id: service.id,
      address: service.address,
      workTime: service.workTime
    });
  } catch (error) {
    logger.error('Ошибка обновления данных сервиса', error);
    res.status(400).json({ error: error.message });
  }
});

app.delete("/services/:id", async (req, res) => {
  try {
    const serviceId = Number(req.params.id);

    logger.info('Удаление сервиса и связанных данных', { serviceId });
    
    logger.debug('Начало транзакции по удалению сервиса');
    const result = await prisma.$transaction(async (tx) => {

      logger.debug('1. Обнуление mechanicId в связанных заявках');
      await tx.request.updateMany({
        where: {
          mechanic: { serviceId: serviceId }
        },
        data: { mechanicId: null }
      });

      logger.debug('2. Обнуление serviceId в заявках');
      await tx.request.updateMany({
        where: { serviceId: serviceId },
        data: { serviceId: null }
      });

      logger.debug('3. Получение списка механиков сервиса');
      const mechanics = await tx.mechanic.findMany({
        where: { serviceId: serviceId },
        select: { id: true }
      });

      if (mechanics.length > 0) {
        const ids = mechanics.map(m => m.id);
        logger.debug(`Найдено ${mechanics.length} механиков для удаления`, { ids });

        logger.debug('3.1. Обнуление mechanicId в заявках на удаляемых механиков');
        await tx.request.updateMany({
          where: { mechanicId: { in: ids } },
          data: { mechanicId: null }
        });

        logger.debug('3.2. Удаление механиков сервиса');
        await tx.mechanic.deleteMany({
          where: { id: { in: ids } }
        });
      } else {
        logger.debug('Механиков для удаления не найдено');
      }

      logger.debug('4. Удаление менеджера сервиса');
      const deletedManagers = await tx.manager.deleteMany({
        where: { serviceId: serviceId }
      });
      logger.debug(`Удалено менеджеров: ${deletedManagers.count}`);

      logger.debug('5. Удаление сервиса');
      return await tx.service.delete({
        where: { id: serviceId }
      });
    });

    logger.success('Сервис и все связанные сущности успешно удалены', { 
      serviceId,
      deletedService: result 
    });
    
    res.json({
      success: true,
      message: "Сервис и все связанные сущности успешно удалены",
      deleted: result
    });

  } catch (error) {
    logger.error("Ошибка удаления сервиса", error);
    res.status(400).json({ error: error.message });
  }
});


// ==================== ЗАЯВКИ МЕХАНИКА ====================
app.get("/mechanic/requests/:mechanicId", async (req, res) => {
  try {
    const { mechanicId } = req.params;
    
    logger.info('Получение заявок механика', { mechanicId });
    
    const requests = await prisma.request.findMany({
      where: { 
        mechanicId: parseInt(mechanicId),
        status: { not: "завершена" }
      },
      include: { 
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }, 
        transport: true, 
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        } 
      },
      orderBy: { submittedAt: 'desc' }
    });
    
    logger.success('Заявки механика получены', { 
      mechanicId,
      count: requests.length 
    });
    res.json(requests);
  } catch (error) {
    logger.error('Ошибка получения заявок механика', error);
    res.status(400).json({ error: error.message });
  }
});

// НОВЫЙ ЭНДПОИНТ для завершения заявки (был в API, но не в сервере)
app.put("/requests/:id/complete", async (req, res) => {
  try {
    const { id } = req.params;
    
    logger.info('Завершение заявки', { id });
    
    const request = await prisma.request.update({
      where: { id: parseInt(id) },
      data: {
        status: "завершена",
        closedAt: new Date()
      },
      include: {
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        transport: true,
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        }
      }
    });
    
    logger.success('Заявка завершена', { 
      id: request.id,
      closedAt: request.closedAt 
    });
    
    res.json(request);
  } catch (error) {
    logger.error('Ошибка завершения заявки', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ДЛЯ АДМИНИСТРАТОРА ====================
app.get("/all-requests", async (req, res) => {
  try {
    logger.info('Получение всех заявок для администратора');
    
    const requests = await prisma.request.findMany({
      include: {
        applicant: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        transport: true,
        mechanic: {
          select: {
            id: true,
            name: true,
            email: true
          }
        },
        service: {
          select: {
            id: true,
            address: true,
            workTime: true
          }
        }
      },
      orderBy: {
        submittedAt: 'desc'
      }
    });
    
    logger.success('Все заявки получены', { count: requests.length });
    res.json(requests);
  } catch (error) {
    logger.error('Ошибка получения всех заявок', error);
    res.status(400).json({ error: error.message });
  }
});

app.get("/all-transports", async (req, res) => {
  try {
    logger.info('Получение всего транспорта для администратора');
    
    const transports = await prisma.transport.findMany({
      include: {
        requests: {
          select: {
            id: true,
            problem: true,
            status: true
          }
        }
      }
    });
    
    logger.success('Весь транспорт получен', { count: transports.length });
    res.json(transports);
  } catch (error) {
    logger.error('Ошибка получения всего транспорта', error);
    res.status(400).json({ error: error.message });
  }
});

// НОВЫЙ ЭНДПОИНТ: Получение всех данных для админ-панели
app.get("/admin/all-data", async (req, res) => {
  try {
    logger.info('Загрузка всех данных для админ-панели');
    
    logger.debug('Начало параллельной загрузки данных');
    const [services, managers, mechanics, applicants, requests] = await Promise.all([
      prisma.service.findMany({
        select: {
          id: true,
          address: true,
          workTime: true
        }
      }),
      prisma.manager.findMany({
        select: {
          id: true,
          name: true,
          email: true,
          photo: true,
          role: true,
          serviceId: true
        }
      }),
      prisma.mechanic.findMany({
        select: {
          id: true,
          name: true,
          email: true,
          photo: true,
          role: true,
          serviceId: true
        }
      }),
      prisma.applicant.findMany({
        select: {
          id: true,
          name: true,
          email: true,
          photo: true,
          role: true
        }
      }),
      prisma.request.findMany({
        include: {
          applicant: {
            select: {
              id: true,
              name: true,
              email: true
            }
          },
          transport: true,
          mechanic: {
            select: {
              id: true,
              name: true,
              email: true
            }
          },
          service: {
            select: {
              id: true,
              address: true,
              workTime: true
            }
          }
        },
        orderBy: {
          submittedAt: 'desc'
        }
      })
    ]);
    
    logger.success('Все данные загружены', {
      services: services.length,
      managers: managers.length,
      mechanics: mechanics.length,
      applicants: applicants.length,
      requests: requests.length
    });
    
    res.json({
      services,
      managers,
      mechanics,
      applicants,
      requests
    });
  } catch (error) {
    logger.error('Ошибка загрузки всех данных', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ДЕБАГ ИНФОРМАЦИЯ ====================
app.get("/debug/database", async (req, res) => {
  try {
    logger.info('Получение отладочной информации о базе данных');
    
    logger.debug('Подсчет записей в таблицах');
    const [servicesCount, transportsCount, requestsCount, applicantsCount, mechanicsCount, managersCount] = await Promise.all([
      prisma.service.count(),
      prisma.transport.count(),
      prisma.request.count(),
      prisma.applicant.count(),
      prisma.mechanic.count(),
      prisma.manager.count()
    ]);
    
    logger.debug('Получение последних заявок');
    const recentRequests = await prisma.request.findMany({
      take: 5,
      orderBy: { id: 'desc' },
      include: { 
        transport: true, 
        service: true, 
        applicant: true, 
        mechanic: true 
      }
    });
    
    logger.success('Отладочная информация получена', {
      counts: {
        services: servicesCount,
        transports: transportsCount,
        requests: requestsCount,
        applicants: applicantsCount,
        mechanics: mechanicsCount,
        managers: managersCount
      }
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
    logger.error('Ошибка получения отладочной информации', error);
    res.status(400).json({ error: error.message });
  }
});

//новые эндпоинты 05.12.2025 22:22

// ==================== ДОПОЛНИТЕЛЬНЫЕ ЭНДПОИНТЫ ====================

// Получение профиля пользователя по ID и роли
app.get("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.query;
    
    logger.info('Получение профиля пользователя', { id, role });
    
    let user = null;
    
    switch(role) {
      case 'applicant':
        logger.debug('Поиск заявителя');
        user = await prisma.applicant.findUnique({
          where: { id: parseInt(id) },
          select: {
            id: true,
            name: true,
            email: true,
            photo: true,
            role: true,
            password: false
          }
        });
        break;
        
      case 'mechanic':
        logger.debug('Поиск механика');
        user = await prisma.mechanic.findUnique({
          where: { id: parseInt(id) },
          select: {
            id: true,
            name: true,
            email: true,
            photo: true,
            role: true,
            serviceId: true,
            password: false
          }
        });
        break;
        
      case 'manager':
        logger.debug('Поиск менеджера');
        user = await prisma.manager.findUnique({
          where: { id: parseInt(id) },
          select: {
            id: true,
            name: true,
            email: true,
            photo: true,
            role: true,
            serviceId: true,
            password: false
          }
        });
        break;
        
      default:
        logger.warn('Не указана роль при получении профиля', { id, role });
        return res.status(400).json({ error: 'Не указана роль' });
    }
    
    if (!user) {
      logger.warn('Пользователь не найден', { id, role });
      return res.status(404).json({ error: 'Пользователь не найден' });
    }
    
    logger.success('Профиль пользователя получен', { 
      id: user.id, 
      name: user.name,
      role: role 
    });
    
    res.json(user);
  } catch (error) {
    logger.error('Ошибка получения профиля', error);
    res.status(400).json({ error: error.message });
  }
});

// Обновление профиля пользователя
app.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { role, ...updateData } = req.body;
    
    logger.info('Обновление профиля пользователя', { id, role });
    
    // Скрываем пароль в логах
    const logData = { ...updateData };
    if (logData.password) {
      logData.password = '***HIDDEN***';
    }
    logger.debug('Данные для обновления', logData);
    
    // Убираем пароль если он пустой
    if (updateData.password === '' || updateData.password === null) {
      delete updateData.password;
    }
    
    let updatedUser = null;
    
    switch(role) {
      case 'applicant':
        logger.debug('Обновление заявителя');
        updatedUser = await prisma.applicant.update({
          where: { id: parseInt(id) },
          data: updateData,
          select: {
            id: true,
            name: true,
            email: true,
            photo: true,
            role: true,
            password: false
          }
        });
        break;
        
      case 'mechanic':
        logger.debug('Обновление механика');
        updatedUser = await prisma.mechanic.update({
          where: { id: parseInt(id) },
          data: updateData,
          select: {
            id: true,
            name: true,
            email: true,
            photo: true,
            role: true,
            serviceId: true,
            password: false
          }
        });
        break;
        
      case 'manager':
        logger.debug('Обновление менеджера');
        updatedUser = await prisma.manager.update({
          where: { id: parseInt(id) },
          data: updateData,
          select: {
            id: true,
            name: true,
            email: true,
            photo: true,
            role: true,
            serviceId: true,
            password: false
          }
        });
        break;
        
      default:
        logger.warn('Не указана роль при обновлении профиля', { id, role });
        return res.status(400).json({ error: 'Не указана роль' });
    }
    
    logger.success('Профиль обновлен', { 
      id: updatedUser.id, 
      name: updatedUser.name 
    });
    
    res.json(updatedUser);
  } catch (error) {
    logger.error('Ошибка обновления профиля', error);
    res.status(400).json({ error: error.message });
  }
});

// Получение деталей сервиса
app.get("/services/:id/details", async (req, res) => {
  try {
    const { id } = req.params;
    
    logger.info('Получение деталей сервиса', { id });
    
    const service = await prisma.service.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        address: true,
        workTime: true,
        manager: {
          select: {
            id: true,
            name: true
          }
        }
      }
    });
    
    if (!service) {
      logger.warn('Сервис не найден при получении деталей', { id });
      return res.status(404).json({ error: 'Сервис не найден' });
    }
    
    logger.success('Детали сервиса получены', { 
      id: service.id, 
      address: service.address 
    });
    
    res.json(service);
  } catch (error) {
    logger.error('Ошибка получения деталей сервиса', error);
    res.status(400).json({ error: error.message });
  }
});

// ==================== ЗАЯВКИ ЗАЯВИТЕЛЯ ====================
app.get("/applicant/requests/:applicantId", async (req, res) => {
  try {
    const { applicantId } = req.params;
    const applicantIdInt = parseInt(applicantId);

    if (isNaN(applicantIdInt)) {
      logger.warn('Некорректный ID заявителя', { applicantId });
      return res.status(400).json({ error: 'Некорректный ID заявителя.' });
    }

    logger.info('Загрузка заявок для заявителя', { applicantId: applicantIdInt });

    const requests = await prisma.request.findMany({
      where: { 
        applicantId: applicantIdInt
      },
      include: { 
        applicant: {
          select: { id: true, name: true, email: true }
        }, 
        mechanic: {
          select: { id: true, name: true, email: true }
        }, 
        transport: true, 
        service: {
          select: { id: true, address: true, workTime: true }
        } 
      },
      orderBy: { submittedAt: 'desc' }
    });

    logger.success('Заявки заявителя получены', { 
      applicantId: applicantIdInt,
      count: requests.length 
    });
    
    res.json(requests);
  } catch (error) {
    logger.error('Ошибка загрузки заявок заявителя', error);
    res.status(500).json({ error: 'Внутренняя ошибка сервера: ' + error.message });
  }
});

// ==================== ЗАПУСК СЕРВЕРА ====================
app.listen(PORT, () => {
  logger.info(`🚀 Сервер запущен на http://localhost:${PORT}`);
  logger.info(`📞 API доступен по адресу: http://localhost:${PORT}`);
  
  // Логирование системной информации
  logger.debug('Конфигурация сервера', {
    port: PORT,
    nodeVersion: process.version,
    platform: process.platform,
    memoryUsage: process.memoryUsage()
  });
});