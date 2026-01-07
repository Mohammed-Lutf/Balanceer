// @ts-ignore: Deno module import
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// @ts-ignore: npm specifier for Deno
import { createTransport } from "npm:nodemailer@6.9.13"

// Deno namespace declaration for TypeScript
declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, name } = await req.json()
    if (!email) throw new Error('Email is required')

    const transporter = createTransport({
      service: 'gmail',
      auth: {
        user: Deno.env.get("GMAIL_USER"),
        pass: Deno.env.get("GMAIL_APP_PASSWORD"),
      },
    })

    const info = await transporter.sendMail({
      from: `"Balanceer App" <${Deno.env.get("GMAIL_USER")}>`,
      to: email,
      subject: `مرحبًا ${name || 'ضيف Balanceer'} | بداية مختلفة مع Balanceer`,
      html: `
<div style="direction:rtl;font-family:Tahoma;background:#f4f6f9;padding:30px 0">
  <div style="max-width:650px;margin:auto;background:#fff;border-radius:14px;box-shadow:0 15px 40px rgba(0,0,0,.08)">
    <div style="background:linear-gradient(135deg,#1e3c72,#2a5298);padding:35px;text-align:center">
      <h1 style="color:#fff;margin:0">Balanceer</h1>
      <p style="color:#dbe6ff">لأن حياتك تستحق إدارة أذكى</p>
    </div>
    <div style="padding:40px;line-height:1.9">
      <p><strong>مرحبًا ${name || 'ضيف Balanceer'}،</strong></p>
      <p>يبدو أن رحلتك في إدارة حياتك بالشكل الصحيح قد بدأت الآن… وهذه ليست مجرد بداية بل نقطة تحوّل.</p>
      <p>مع Balanceer تمتلك السيطرة والوضوح والتخطيط الواعي.</p>
      <p style="font-weight:bold;color:#2a5298;text-align:center">
        مع Balanceer… حياتك أسهل وقراراتك أذكى
      </p>
    </div>
    <div style="background:#f7f9fc;padding:25px;text-align:center">
      فريق Balanceer<br>
      <strong>Eng. Mohammed Akram Lutf</strong>
    </div>
  </div>
</div>
      `,
    })

    return new Response(JSON.stringify({ messageId: info.messageId }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ error: message }), { status: 400 })
  }
})

