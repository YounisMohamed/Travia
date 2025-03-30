// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs

import {createClient} from 'npm:@supabase/supabase-js@2'
import {JWT} from 'npm:google-auth-library@9'
interface Notification {
id: string; // Primary key (UUID as text)
  target_user_id: string | null; // Target user ID (can be null)
  sender_user_id: string | null; // Sender user ID (can be null)
  source_id: string | null; // Source ID (can be null)
  type: string; // Type of the notification
  content: string; // Content of the notification
  created_at: string | null; // Timestamp of creation (ISO string format)
  is_read: boolean; // Whether the notification is read or not
  sender_photo: string | null; // Sender's photo URL (can be null)
  user_username: string | null; // Username of the user (can be null)
}

interface WebhookPayload {
  type: "INSERT"
  table: string
  record: Notification
  schema: "public"
  old_record: null | Notification
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
)


Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    // Fetch all FCM tokens for the target user
    const { data } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", payload.record.target_user_id)
      .single();

    if (!data || !data.fcm_token || data.fcm_token.length === 0) {
      return new Response(JSON.stringify({ error: "No FCM tokens found" }), { status: 400 });
    }

    const fcmTokens = data.fcm_token as string[];

    // Import Firebase service account credentials
    const { default: serviceAccount } = await import("../service-account.json", {
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
              title: payload.record.type,
              body: payload.record.content,
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

    return new Response(JSON.stringify({ success: "Notifications sent" }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Error sending notification:", error);
    return new Response(JSON.stringify({ error: "Internal Server Error" }), { status: 500 });
  }
});

/* To invoke locally:

1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
2. Make an HTTP request:

curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/notifications' \
--header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
--header 'Content-Type: application/json' \
--data '{"name":"Functions"}'

*/


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
