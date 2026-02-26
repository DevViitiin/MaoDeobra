import * as admin from "firebase-admin";
import { onValueCreated } from "firebase-functions/v2/database";
import { logger } from "firebase-functions/v2";

// Inicializa imediatamente
admin.initializeApp();

// ============================================================
// HELPERS - PUSH NOTIFICATIONS
// ============================================================

async function getSenderInfo(userId: string) {
  try {
    const userSnap = await admin.database().ref(`Users/${userId}`).once("value");
    if (!userSnap.exists()) {
      return { name: "Usuário", avatar: "" };
    }
    const userData = userSnap.val() as Record<string, any>;
    return {
      name: userData?.Name || "Usuário",
      avatar: userData?.avatar || "",
    };
  } catch (error) {
    return { name: "Usuário", avatar: "" };
  }
}

async function isUserOnlineInChat(
  chatId: string,
  userRole: "employee" | "contractor"
): Promise<boolean> {
  try {
    const statusSnap = await admin.database()
      .ref(`Chats/${chatId}/participants/${userRole}`)
      .once("value");
    return statusSnap.val() === "online";
  } catch (error) {
    return false;
  }
}

async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>,
  imageUrl?: string
) {
  try {
    const tokenSnap = await admin.database().ref(`Users/${userId}/fcmToken`).once("value");

    if (!tokenSnap.exists()) {
      logger.info(`Usuário ${userId} não tem FCM token`);
      return;
    }

    const token = tokenSnap.val() as string;

    const message: admin.messaging.Message = {
      token,
      notification: {
        title,
        body,
        imageUrl: imageUrl || undefined,
      },
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "chat_messages",
          priority: "high",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    logger.info(`Push notification enviada para ${userId}`);
  } catch (error: any) {
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      await admin.database().ref(`Users/${userId}/fcmToken`).remove();
    } else {
      logger.error("Erro ao enviar push", { error });
    }
  }
}

// ============================================================
// HELPER - RECALCULAR BADGE (USA MESMA LÓGICA DO DART)
// ============================================================

async function recalculateChatBadge(userId: string) {
  try {
    logger.info(`\n🔄🔄🔄 RECALCULANDO BADGE 🔄🔄🔄`);
    logger.info(`UserId: ${userId}`);

    // Busca TODOS os chats como EMPLOYEE
    const employeeChatsSnap = await admin.database()
      .ref("Chats")
      .orderByChild("employee")
      .equalTo(userId)
      .once("value");

    // Busca TODOS os chats como CONTRACTOR
    const contractorChatsSnap = await admin.database()
      .ref("Chats")
      .orderByChild("contractor")
      .equalTo(userId)
      .once("value");

    let totalUnread = 0;

    // Conta chats não lidos como EMPLOYEE
    if (employeeChatsSnap.exists()) {
      const chats = employeeChatsSnap.val() as Record<string, any>;
      logger.info(`Chats como employee: ${Object.keys(chats).length}`);
      
      for (const chatId in chats) {
        const chat = chats[chatId];
        const unreadCount = chat.unreadCount?.employee || 0;
        
        if (unreadCount === 1) {
          totalUnread++;
          logger.info(`  ✉️ Chat não lido (employee): ${chatId}`);
        }
      }
    }

    // Conta chats não lidos como CONTRACTOR
    if (contractorChatsSnap.exists()) {
      const chats = contractorChatsSnap.val() as Record<string, any>;
      logger.info(`Chats como contractor: ${Object.keys(chats).length}`);
      
      for (const chatId in chats) {
        const chat = chats[chatId];
        const unreadCount = chat.unreadCount?.contractor || 0;
        
        if (unreadCount === 1) {
          totalUnread++;
          logger.info(`  ✉️ Chat não lido (contractor): ${chatId}`);
        }
      }
    }

    // Limita a 9
    totalUnread = Math.min(totalUnread, 9);

    // Pega badge atual para manter unread_requests
    const badgeSnap = await admin.database()
      .ref(`badges/${userId}`)
      .once("value");

    const currentBadge = badgeSnap.exists() 
      ? badgeSnap.val() 
      : { unread_requests: 0 };

    // Atualiza badge
    await admin.database().ref(`badges/${userId}`).set({
      unread_chats: totalUnread,
      unread_requests: currentBadge.unread_requests || 0,
      updated_at: Date.now(),
    });

    logger.info(`✅ Badge recalculado: ${totalUnread} chats não lidos`);
    logger.info(`✅✅✅ RECÁLCULO CONCLUÍDO ✅✅✅\n`);

  } catch (error) {
    logger.error(`❌ Erro ao recalcular badge:`, error);
  }
}

async function incrementRequestBadge(userId: string) {
  try {
    const badgeRef = admin.database().ref(`badges/${userId}`);
    const snap = await badgeRef.once("value");
    
    const current = snap.exists() 
      ? snap.val() 
      : { unread_chats: 0, unread_requests: 0 };

    await badgeRef.set({
      unread_chats: current.unread_chats || 0,
      unread_requests: Math.min((current.unread_requests || 0) + 1, 9),
      updated_at: Date.now(),
    });
  } catch (error) {
    logger.error("Erro ao incrementar request badge:", error);
  }
}

// ============================================================
// FUNCTION - NEW CHAT MESSAGE
// ============================================================

export const onChatMessageCreated = onValueCreated(
  {
    ref: "/ChatMessages/{chatId}/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const chatId = event.params.chatId;
    const messageData = event.data.val() as any;

    // Ignora placeholder
    if (messageData._placeholder || !messageData) {
      return;
    }

    try {
      logger.info(`\n════════════════════════════════════════`);
      logger.info(`📨 NOVA MENSAGEM: ${chatId}`);
      logger.info(`════════════════════════════════════════`);

      const chatSnap = await admin.database().ref(`Chats/${chatId}`).once("value");
      if (!chatSnap.exists()) {
        logger.warn(`⚠️ Chat ${chatId} não existe`);
        return;
      }

      const chatData = chatSnap.val() as {
        employee: string;
        contractor: string;
        unreadCount?: { employee: number; contractor: number };
      };

      const { employee, contractor } = chatData;
      const senderRole = messageData.sender as "employee" | "contractor";
      const sender = senderRole === "employee" ? employee : contractor;
      const receiver = senderRole === "employee" ? contractor : employee;
      const receiverRole = senderRole === "employee" ? "contractor" : "employee";

      logger.info(`👤 Sender: ${sender} (${senderRole})`);
      logger.info(`👤 Receiver: ${receiver} (${receiverRole})`);

      // Verifica se receiver está online NO CHAT
      const isOnline = await isUserOnlineInChat(chatId, receiverRole);
      logger.info(`📶 Online: ${isOnline}`);

      // LÓGICA BINÁRIA
      const newUnreadCount = isOnline ? 0 : 1;
      const currentUnreadCount = chatData.unreadCount?.[receiverRole] || 0;

      logger.info(`📊 UnreadCount: ${currentUnreadCount} → ${newUnreadCount}`);

      // 1. Atualiza unreadCount
      await admin.database().ref(`Chats/${chatId}/unreadCount/${receiverRole}`).set(newUnreadCount);
      logger.info(`✅ unreadCount atualizado em Chats/${chatId}/unreadCount/${receiverRole}`);

      // 2. RECALCULA badge (SEMPRE - garante sincronização)
      logger.info(`\n🔔 Recalculando badge do receiver...`);
      await recalculateChatBadge(receiver);

      // 3. Push notification
      if (!isOnline) {
        const senderInfo = await getSenderInfo(sender);
        
        const displayText =
          messageData.text && messageData.text.length > 100
            ? messageData.text.substring(0, 97) + "..."
            : messageData.text || "Nova mensagem";

        await sendPushNotification(
          receiver,
          senderInfo.name,
          displayText,
          {
            type: "chat",
            chatId,
            senderId: sender,
            senderName: senderInfo.name,
            senderAvatar: senderInfo.avatar || "",
          },
          senderInfo.avatar
        );
      }

      logger.info(`\n✅ PROCESSADO COM SUCESSO`);
      logger.info(`════════════════════════════════════════\n`);
      
    } catch (err) {
      logger.error(`\n❌❌❌ ERRO CRÍTICO ❌❌❌`);
      logger.error(`Erro:`, err);
    }
  }
);

// ============================================================
// FUNCTION - WORKER REQUEST
// ============================================================

export const onWorkerRequestCreated = onValueCreated(
  {
    ref: "/professionals/{profileId}/views/request_views/{requestId}",
    region: "us-central1",
  },
  async (event) => {
    const profileId = event.params.profileId;
    const requestData = event.data.val() as any;

    try {
      const profileSnap = await admin.database()
        .ref(`professionals/${profileId}`)
        .once("value");

      if (!profileSnap.exists()) return;

      const profileData = profileSnap.val() as Record<string, any>;
      const ownerId = profileData.local_id as string;

      await incrementRequestBadge(ownerId);

      const requesterName = requestData.contractor_name || "Alguém";
      const requesterAvatar = requestData.contractor_avatar || "";

      await sendPushNotification(
        ownerId,
        "Nova Solicitação de Contato",
        `${requesterName} quer entrar em contato com você`,
        {
          type: "request",
          requestType: "worker",
          profileId,
          requesterName,
          requesterAvatar,
        },
        requesterAvatar
      );

      logger.info(`Worker request criado: ${profileId}`);
    } catch (err) {
      logger.error("Erro em onWorkerRequestCreated", { error: err });
    }
  }
);

// ============================================================
// FUNCTION - VACANCY REQUEST
// ============================================================

export const onVacancyRequestCreated = onValueCreated(
  {
    ref: "/vacancy/{vacancyId}/views/request_views/{requestId}",
    region: "us-central1",
  },
  async (event) => {
    const vacancyId = event.params.vacancyId;
    const requestId = event.params.requestId;

    try {
      const vacancySnap = await admin.database().ref(`vacancy/${vacancyId}`).once("value");
      if (!vacancySnap.exists()) return;

      const vacancyData = vacancySnap.val() as Record<string, any>;
      const ownerId = vacancyData.local_id as string;

      await incrementRequestBadge(ownerId);

      const requesterSnap = await admin.database().ref(`Users/${requestId}`).once("value");
      let requesterName = "Alguém";
      let requesterAvatar = "";

      if (requesterSnap.exists()) {
        const requesterData = requesterSnap.val() as Record<string, any>;
        requesterName = requesterData.Name || "Alguém";
        requesterAvatar = requesterData.avatar || "";
      }

      await sendPushNotification(
        ownerId,
        "Novo Interesse na Vaga",
        `${requesterName} tem interesse na sua vaga`,
        {
          type: "request",
          requestType: "contractor",
          vacancyId,
          requesterName,
          requesterAvatar,
        },
        requesterAvatar
      );

      logger.info(`Vacancy request criado: ${vacancyId}`);
    } catch (err) {
      logger.error("Erro em onVacancyRequestCreated", { error: err });
    }
  }
);

// ============================================================
// FUNCTION - CHAT CREATED
// ============================================================

export const onChatCreated = onValueCreated(
  {
    ref: "/Chats/{chatId}",
    region: "us-central1",
  },
  async (event) => {
    const chatId = event.params.chatId;
    const chatData = event.data.val() as any;

    if (!chatData) return;

    try {
      const { employee, contractor } = chatData;

      const [employeeInfo, contractorInfo] = await Promise.all([
        getSenderInfo(employee),
        getSenderInfo(contractor),
      ]);

      await Promise.all([
        sendPushNotification(
          employee,
          "Solicitação Aceita! 🎉",
          `${contractorInfo.name} aceitou sua solicitação de chat`,
          {
            type: "chat_accepted",
            chatId,
            senderId: contractor,
            senderName: contractorInfo.name,
            senderAvatar: contractorInfo.avatar || "",
          },
          contractorInfo.avatar
        ),
        sendPushNotification(
          contractor,
          "Solicitação Aceita! 🎉",
          `${employeeInfo.name} aceitou sua solicitação de chat`,
          {
            type: "chat_accepted",
            chatId,
            senderId: employee,
            senderName: employeeInfo.name,
            senderAvatar: employeeInfo.avatar || "",
          },
          employeeInfo.avatar
        ),
      ]);

      logger.info(`Notificações enviadas: ${chatId}`);
    } catch (err) {
      logger.error("Erro em onChatCreated", { error: err });
    }
  }
);