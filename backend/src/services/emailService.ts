import nodemailer from 'nodemailer';

/**
 * Email service using SMTP (Gmail).
 *
 * Required env vars:
 *   SMTP_HOST    – SMTP server host (e.g., smtp.gmail.com)
 *   SMTP_PORT    – SMTP port (usually 587 for TLS)
 *   SMTP_USER    – Email address
 *   SMTP_PASS    – App password or email password
 *   SMTP_FROM    – Sender address (e.g., "FamilySphere <kananijeeel00@gmail.com>")
 */

let transporter: nodemailer.Transporter | null = null;

const getTransporter = (): nodemailer.Transporter | null => {
    if (transporter) return transporter;

    const host = process.env.SMTP_HOST;
    const port = process.env.SMTP_PORT;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (!host || !port || !user || !pass) {
        return null;
    }

    transporter = nodemailer.createTransport({
        host,
        port: parseInt(port, 10),
        secure: parseInt(port, 10) === 465, // Use TLS for 587, SSL for 465
        auth: {
            user,
            pass,
        },
    });

    return transporter;
};

export const sendEmailOtp = async (to: string, code: string) => {
    const transporter = getTransporter();
    const from = process.env.SMTP_FROM || 'FamilySphere <noreply@familysphere.com>';
    const subject = 'FamilySphere verification code';
    const text = `Your FamilySphere verification code is: ${code}. It expires in 10 minutes.`;
    const html = `
        <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
            <h2 style="color: #6C63FF; margin-bottom: 24px;">FamilySphere</h2>
            <p style="font-size: 16px; color: #333;">Your verification code is:</p>
            <div style="background: #f4f4f8; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
                <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #6C63FF;">${code}</span>
            </div>
            <p style="font-size: 14px; color: #666;">This code expires in 10 minutes. If you didn't request this, please ignore this email.</p>
        </div>
    `;

    if (!transporter) {
        // Fallback for dev when SMTP isn't configured
        // eslint-disable-next-line no-console
        console.log(`[Email OTP] ${to} -> ${code}`);
        return;
    }

    try {
        await transporter.sendMail({
            from,
            to,
            subject,
            text,
            html,
        });
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        console.error('[OTP] SMTP error:', errorMessage);
        throw new Error(`Email send failed: ${errorMessage}`);
    }
};

export const sendFamilyInviteEmail = async (to: string, inviterName: string, familyName: string, inviteUrl: string) => {
    const transporter = getTransporter();
    const from = process.env.SMTP_FROM || 'FamilySphere <noreply@familysphere.com>';
    const subject = `Join ${familyName} on FamilySphere`;
    const text = `${inviterName} has invited you to join their family "${familyName}" on FamilySphere. Use this link: ${inviteUrl}`;
    const html = `
        <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
            <h2 style="color: #6C63FF; margin-bottom: 24px;">FamilySphere</h2>
            <p style="font-size: 16px; color: #333;"><strong>${inviterName}</strong> has invited you to join the family:</p>
            <h3 style="color: #333; margin: 16px 0;">${familyName}</h3>
            <div style="margin: 32px 0;">
                <a href="${inviteUrl}" target="_blank" style="background: #6C63FF; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; display: inline-block;">Accept Invitation</a>
            </div>
            <p style="font-size: 14px; color: #666;">This invitation expires in 48 hours. If the button doesn't work, copy and paste this link:<br>${inviteUrl}</p>
        </div>
    `;

    if (!transporter) {
        // eslint-disable-next-line no-console
        console.log(`[Email Invite] ${to} -> ${inviteUrl}`);
        return;
    }

    try {
        await transporter.sendMail({
            from,
            to,
            subject,
            text,
            html,
        });
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        console.error('[Invite] SMTP error:', errorMessage);
        throw new Error(`Invitation email failed: ${errorMessage}`);
    }
};
