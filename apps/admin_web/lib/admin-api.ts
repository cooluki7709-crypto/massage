const API_BASE_URL = process.env.ADMIN_API_BASE_URL ?? 'http://localhost:3000/api';

export type AdminUser = {
  id: string;
  phone: string;
  fullName?: string | null;
  roles: string[];
  providerProfile?: AdminProvider | null;
};

export type AdminProvider = {
  id: string;
  displayName: string;
  status: string;
  verification?: {
    id: string;
    status: string;
    submittedAt?: string | null;
    reviewedAt?: string | null;
    rejectionReason?: string | null;
    files?: Array<{ id: string; key: string; contentType: string; visibility: string; url?: string | null }>;
  } | null;
  services?: Array<{ service?: { name: string } }>;
  user?: {
    fullName?: string | null;
    phone?: string;
    pushDevices?: Array<{
      id: string;
      platform: string;
      enabled: boolean;
      token: string;
      createdAt?: string;
      deliveries?: Array<{
        id: string;
        status: string;
        attemptedAt: string;
        provider: string;
        response?: {
          statusCode?: number;
          body?: {
            error?: {
              details?: Array<{
                errorCode?: string;
              }>;
            };
          };
        } | null;
      }>;
    }>;
  };
};

export type AdminBooking = {
  id: string;
  status: string;
  createdAt?: string;
  scheduledStartAt?: string;
  expiresAt?: string | null;
  participants?: Array<{
    id: string;
    status: string;
    providerProfile?: {
      id: string;
      displayName?: string | null;
      status?: string;
      user?: { fullName?: string | null; phone?: string };
    };
  }>;
  services?: Array<{ service?: { name?: string; durationMin?: number; basePrice?: number } }>;
  payment?: { status: string; amount: number; method: string } | null;
  customerProfile?: { user?: { fullName?: string | null; phone?: string } };
  selectedProvider?: { id?: string; displayName?: string | null; status?: string; user?: { phone?: string; fullName?: string | null } };
  chatRoom?: { id: string } | null;
};

export type AdminPayment = {
  id: string;
  method: string;
  status: string;
  amount: number;
  currency: string;
  bookingId: string;
  providerRef?: string | null;
  rawMeta?: unknown;
  booking?: {
    status?: string;
    customerProfile?: { user?: { phone?: string; fullName?: string | null } };
    selectedProvider?: { displayName?: string | null };
  };
  refunds?: Array<{ id: string; amount: number; status: string; createdAt?: string }>;
};

export type AdminEarning = {
  id: string;
  providerProfileId: string;
  bookingId: string;
  grossAmount: number;
  platformFee: number;
  tipAmount: number;
  netAmount: number;
  currency: string;
  status: string;
  availableAt?: string | null;
  paidAt?: string | null;
  payoutBatchId?: string | null;
  providerProfile?: { displayName?: string | null; user?: { phone?: string; fullName?: string | null } };
};

export type AdminEarningSummary = {
  count: number;
  grossAmount: number;
  platformFee: number;
  tipAmount: number;
  netAmount: number;
  pendingNetAmount: number;
  availableNetAmount: number;
  paidNetAmount: number;
  currency: string;
};

export type AdminRefund = {
  id: string;
  bookingId: string;
  paymentId: string;
  amount: number;
  reason?: string | null;
  status: string;
  createdAt: string;
  booking?: {
    status?: string;
    customerProfile?: { user?: { phone?: string; fullName?: string | null } };
    selectedProvider?: { displayName?: string | null };
  };
  payment?: { method: string; status: string; currency: string };
};

export type AdminPayoutBatch = {
  id: string;
  providerProfileId: string;
  totalNetAmount: number;
  currency: string;
  status: string;
  transferRef?: string | null;
  notes?: string | null;
  createdAt: string;
  paidAt?: string | null;
  providerProfile?: { displayName?: string | null; user?: { phone?: string; fullName?: string | null } };
  earnings?: AdminEarning[];
};

export type AdminReview = {
  id: string;
  rating: number;
  comment?: string | null;
  tipAmount: number;
  status: string;
  reportReason?: string | null;
  customerProfile?: { user?: { fullName?: string | null; phone?: string } };
  providerProfile?: { displayName?: string | null };
};

export type AdminCoupon = {
  id: string;
  code: string;
  description?: string | null;
  discount: unknown;
  active: boolean;
};

export type AdminAuditLog = {
  id: string;
  action: string;
  target: string;
  metadata?: unknown;
  createdAt: string;
  actor?: { phone?: string; fullName?: string | null };
};

export type AdminNotification = {
  id: string;
  type: string;
  title: string;
  body: string;
  createdAt: string;
  user?: { phone?: string; fullName?: string | null };
  deliveries?: Array<{
    id?: string;
    provider: string;
    status: string;
    attemptedAt: string;
    response?: {
      statusCode?: number;
      body?: {
        error?: {
          details?: Array<{
            errorCode?: string;
          }>;
        };
      };
    } | null;
    pushDevice?: { platform?: string; token?: string; enabled?: boolean };
  }>;
};

export async function adminGet<T>(path: string, fallback: T): Promise<T> {
  try {
    const token = await getAdminAccessToken();
    const response = await fetch(`${API_BASE_URL}${path}`, {
      headers: { authorization: `Bearer ${token}` },
      cache: 'no-store',
    });

    if (!response.ok) {
      return fallback;
    }

    return (await response.json()) as T;
  } catch {
    return fallback;
  }
}

export async function adminPost<T>(path: string, body: unknown, fallback: T): Promise<T> {
  try {
    const token = await getAdminAccessToken();
    const response = await fetch(`${API_BASE_URL}${path}`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(body ?? {}),
      cache: 'no-store',
    });

    if (!response.ok) {
      return fallback;
    }

    return (await response.json()) as T;
  } catch {
    return fallback;
  }
}

export async function adminPatch<T>(path: string, body: unknown, fallback: T): Promise<T> {
  try {
    const token = await getAdminAccessToken();
    const response = await fetch(`${API_BASE_URL}${path}`, {
      method: 'PATCH',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(body ?? {}),
      cache: 'no-store',
    });

    if (!response.ok) {
      return fallback;
    }

    return (await response.json()) as T;
  } catch {
    return fallback;
  }
}

async function getAdminAccessToken() {
  if (process.env.ADMIN_ACCESS_TOKEN) {
    return process.env.ADMIN_ACCESS_TOKEN;
  }

  const response = await fetch(`${API_BASE_URL}/auth/verify-otp`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      phone: process.env.ADMIN_DEMO_PHONE ?? '+84900000099',
      otp: process.env.ADMIN_DEMO_OTP ?? '123456',
      role: 'ADMIN',
    }),
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error('Unable to get admin access token');
  }

  const body = (await response.json()) as { accessToken: string };
  return body.accessToken;
}
