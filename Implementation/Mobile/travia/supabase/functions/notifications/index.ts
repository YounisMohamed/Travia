import { createClient } from 'npm:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

interface Notification {
  id: string;
  target_user_id: string | null;
  sender_user_id: string | null;
  source_id: string | null;
  type: string;
  content: string;
  created_at: string | null;
  is_read: boolean;
  sender_photo: string | null;
  user_username: string | null;
  title: string | null;
}

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: Notification;
  schema: "public";
  old_record: null | Notification;
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const { target_user_id, source_id, type, content, title, sender_photo } = payload.record;

    if (!target_user_id) {
      return new Response(JSON.stringify({ error: "No target user ID found" }), { status: 400 });
    }

    const conversationTypes = ['message', 'typing', 'call']; // TODO: Add other conversation types later :)
     
    if (conversationTypes.includes(type) && source_id) {
      // Check if user has notifications enabled for this conversation
      const { data: participantData, error: participantError } = await supabase
        .from("conversation_participants")
        .select("notifications_enabled")
        .eq("conversation_id", source_id)
        .eq("user_id", target_user_id)
        .single();

      if (participantError) {
        console.error("Error checking participant notifications:", participantError);
        return new Response(JSON.stringify({ error: "Error checking participant notifications" }), { status: 400 });
      }

      // If notifications are disabled for this user in this conversation, skip sending
      if (!participantData || !participantData.notifications_enabled) {
        return new Response(JSON.stringify({ 
          message: "Notification skipped - user has disabled notifications for this conversation",
          target_user_id,
          source_id 
        }), { status: 200 });
      }
    }

    // Fetch FCM tokens for the target user
    const { data: userData } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", target_user_id)
      .single();

    if (!userData || !userData.fcm_token || userData.fcm_token.length === 0) {
      return new Response(JSON.stringify({ error: "No FCM tokens found" }), { status: 400 });
    }

    const fcmTokens = userData.fcm_token as string[];

    // Import Firebase service account credentials
    const { default: serviceAccount } = await import("./service-account.json", {
      with: { type: "json" },
    });

    // Get Firebase access token
    const accessToken = await getAccessToken({
      clientEmail: serviceAccount.client_email,
      privateKey: serviceAccount.private_key,
    });

    // Send notifications to all FCM tokens
    const sendNotification = async (token: string) => {
      return await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: {
              title: title,
              body: content,
              image: sender_photo,
            },
            android: {
              notification: {
                icon: "ic_launcher", 
                color: "#b60f68", 
                default_sound: true,
                default_vibrate_timings: true,
                notification_priority: "PRIORITY_HIGH",
                visibility: "PUBLIC"
              }
            },
            data: {
              type: type,
              source_id: source_id,
            },
          },
        }),
      });
    };

    // Send notifications in parallel
    const responses = await Promise.all(fcmTokens.map(sendNotification));

    // Check if any request failed
    const failedResponses = responses.filter((res) => res.status < 200 || res.status > 299);
    if (failedResponses.length > 0) {
      return new Response(JSON.stringify({ error: "Some notifications failed" }), { status: 500 });
    }

    return new Response(JSON.stringify({ 
      success: "Notifications sent",
      target_user_id,
      source_id,
      type
    }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Error sending notification:", error);
    return new Response(JSON.stringify({ error: "Internal Server Error" }), { status: 500 });
  }
});

const getAccessToken = ({
  clientEmail,
  privateKey
}: {
  clientEmail: string,
  privateKey: string
}): Promise<string> => {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: clientEmail,
      key: privateKey.replace(/\\n/g, '\n'),      
      scopes: [
        'https://www.googleapis.com/auth/firebase.messaging'
      ],
    })
    jwtClient.authorize((err, token) => {
      if (err) {
        reject(err)
        return;
      } else {
        resolve(token?.access_token!)
      }
    })
  })
}