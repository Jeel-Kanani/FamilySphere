import nodemailer from 'nodemailer';

const getTransporter = () => {
    const host = process.env.SMTP_HOST;
    const port = process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : undefined;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (!host || !port || !user || !pass) {
        return null;
    }

    return nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
    });
};

export const sendEmailOtp = async (to: string, code: string) => {
    const transporter = getTransporter();
    const from = process.env.SMTP_FROM || 'no-reply@familysphere.app';
    const subject = 'FamilySphere verification code';
    const text = `Your FamilySphere verification code is: ${code}. It expires in 10 minutes.`;

    if (!transporter) {
        // Fallback for dev when SMTP isn't configured.
        // eslint-disable-next-line no-console
        console.log(`[Email OTP] ${to} -> ${code}`);
        return;
    }

    await transporter.sendMail({ from, to, subject, text });
};
