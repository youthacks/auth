const API_URL = (import.meta.env.BACKEND_URL || 'https://auth.youthacks.org/api').replace(/\/$/, "");
interface ApiResponse<T = any> {
  data?: T;
  error?: string;
  errors?: string[];
  message?: string;
}

class ApiClient {
    clearTokens() {
      this.accessToken = undefined;
      this.refreshToken = undefined;
      if (typeof window !== 'undefined') {
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.removeItem('user');
      }
    }
  private baseURL: string;

  constructor(baseURL: string) {
    this.baseURL = baseURL;
    
  }

  private accessToken?: string;
  private refreshToken?: string;

  private async request<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;
    const headers = new Headers(options.headers || {});
    headers.set('Content-Type', 'application/json');

    // Attach Bearer token if available
    if (!headers.has('Authorization')) {
      const token = this.accessToken || (typeof window !== 'undefined' ? localStorage.getItem('access_token') : undefined);
      if (token) {
        headers.set('Authorization', `Bearer ${token}`);
      }
    }

    try {
      const response = await fetch(url, {
        ...options,
        headers,
      });

      const serverErrorMessage = 'Server error. Please try again or contact us at hello@youthacks.org';
      let data: any = null;
      try {
        const text = await response.text();
        data = text ? JSON.parse(text) : null;
      } catch {
        if (!response.ok || response.status >= 500) {
          return { error: serverErrorMessage };
        }
      }

      if (!response.ok) {
        if (response.status >= 500) {
          return { error: serverErrorMessage };
        }

        return {
          error: data?.error || data?.errors?.[0] || response.statusText || 'Request failed',
          errors: data?.errors,
        };
      }

      return { data };
    } catch (error) {
      return {
        error: error instanceof Error ? error.message : 'Network error',
      };
    }
  }

  setTokens(accessToken: string, refreshToken: string) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    
    if (typeof window !== 'undefined') {
      localStorage.setItem('access_token', accessToken);
      localStorage.setItem('refresh_token', refreshToken);
    }
  }



  clearLocalSession() {
    this.clearTokens();
  }

  async signup(data: {
    first_name: string;
    last_name: string;
    preferred_name?: string;
    username: string;
    email: string;
    password: string;
    password_confirmation: string;
  }) {
    return this.request('/v1/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ user: data }),
    });
  }

  async verifyEmail(email: string, email_code: string) {
    return this.request<{ user: any; message: string }>('/v1/auth/verify_email', {
      method: 'POST',
      body: JSON.stringify({ email, email_code }),
    });
  }

  async resendVerification(email: string) {
    return this.request('/v1/auth/resend_email_verification', {
      method: 'POST',
      body: JSON.stringify({ email }),
    });
  }

  async login(identifier: string, password: string) {
    const response = await this.request<{
      user: any;
      access_token: string;
    }>('/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password }),
    });

    if (response.data) {
      // Use .access_token as accessToken for Bearer auth
      this.setTokens(response.data.access_token, '');
      if (typeof window !== 'undefined') {
        localStorage.setItem('user', JSON.stringify(response.data.user));
      }
    }
    return response;
  }

  async forgotPassword(identifier: string) {
    return this.request<{ message: string; code?: string | null }>('/v1/auth/forgot_password', {
      method: 'POST',
      body: JSON.stringify({ identifier }),
    });
  }

  async refresh() {
    if (!this.refreshToken) {
      return { error: 'No refresh token available' };
    }

    const response = await this.request<{
      access_token: string;
      user: any;
    }>('/v1/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refresh_token: this.refreshToken }),
    });

    if (response.data) {
      this.accessToken = response.data.access_token;
      if (typeof window !== 'undefined') {
        localStorage.setItem('access_token', response.data.access_token);
        localStorage.setItem('user', JSON.stringify(response.data.user));
      }
    }

    return response;
  }

  async logout() {
    const response = await this.request('/v1/auth/logout', {
      method: 'POST',
      body: JSON.stringify({ refresh_token: this.refreshToken }),
    });

    this.clearTokens();
    return response;
  }

  async listAdminClients() {
    return this.request('/v1/admin/clients', {
      method: 'GET',
    });
  }

  async createAdminClient(data: {
    name: string;
    redirect_uri: string;
    scopes?: string;
    confidential?: boolean;
  }) {
    return this.request('/v1/admin/clients', {
      method: 'POST',
      body: JSON.stringify({ application: data }),
    });
  }

  async updateAdminClient(
    id: string | number,
    data: {
      name: string;
      redirect_uri: string;
      scopes?: string;
      confidential?: boolean;
    }
  ) {
    return this.request(`/v1/admin/clients/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ application: data }),
    });
  }

  async deleteAdminClient(id: string | number) {
    return this.request(`/v1/admin/clients/${id}`, {
      method: 'DELETE',
    });
  }

  async serverStatus(timeoutMs: number = 5000): Promise<boolean> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await this.request('/', {
        method: 'GET',
        signal: controller.signal,
      });

      return !response.error;
    } finally {
      clearTimeout(timeoutId);
    }
  }

  async getUser() {
    const response = await this.request('/v1/user', { method: 'GET' });
    if (!response.data) {
      return null;
    }

    if ((response.data as any).user) {
      return (response.data as any).user;
    }

    if ((response.data as any).username && (response.data as any).email) {
      return response.data as any;
    }

    return null;
  }

  async isAuthenticated() {
    const user = await this.getUser();
    return !!user;
  }
}

export const api = new ApiClient(API_URL);
