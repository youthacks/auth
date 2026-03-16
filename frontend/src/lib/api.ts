const API_URL = (import.meta.env.BACKEND_URL || 'http://localhost:3000').replace(/\/$/, "");
interface ApiResponse<T = any> {
  data?: T;
  error?: string;
  errors?: string[];
  message?: string;
}

interface OAuthAuthorizeResponse {
  requires_login?: boolean;
  login_url?: string;
  redirect_url?: string;
  error?: string;
  reason?: string;
}

interface OAuthTokenResponse {
  access_token?: string;
  token_type?: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
  id_token?: string;
  error?: string;
  error_description?: string;
}

class ApiClient {
    clearLegacyStorage() {
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

  private async request<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;
    const headers = new Headers(options.headers || {});
    headers.set('Content-Type', 'application/json');

    try {
      const response = await fetch(url, {
        ...options,
        headers,
        credentials: 'include',
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
          data,
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

  clearLocalSession() {
    this.clearLegacyStorage();
    void this.logout();
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
    }>('/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password }),
    });

    return response;
  }

  async forgotPassword(identifier: string) {
    return this.request<{ message: string; code?: string | null }>('/v1/auth/forgot_password', {
      method: 'POST',
      body: JSON.stringify({ identifier }),
    });
  }

  async refresh() {
    return this.request('/v1/auth/refresh', {
      method: 'POST',
    });
  }

  async oauthRefreshToken(payload: {
    refresh_token: string;
    client_id: string;
    client_secret?: string;
    scope?: string;
  }): Promise<ApiResponse<OAuthTokenResponse>> {
    return this.oauthToken({
      grant_type: 'refresh_token',
      ...payload,
    });
  }

  async logout() {
    const response = await this.request<{ message?: string }>('/v1/auth/logout', {
      method: 'POST',
    });

    this.clearLegacyStorage();
    return response;
  }

  async oauthAuthorize(query: URLSearchParams | string = ''): Promise<ApiResponse<OAuthAuthorizeResponse>> {
    const queryParams = typeof query === 'string' ? new URLSearchParams(query.replace(/^\?/, '')) : query;
    const payload: Record<string, string> = {};
    queryParams.forEach((value, key) => {
      payload[key] = value;
    });

    return this.request<OAuthAuthorizeResponse>('/v1/oidc/authorize/validate', {
      method: 'POST',
      headers: {
        Accept: 'application/json',
      },
      body: JSON.stringify(payload),
    });
  }

  async oauthToken(payload: Record<string, string>): Promise<ApiResponse<OAuthTokenResponse>> {
    const headers = new Headers({
      Accept: 'application/json',
      'Content-Type': 'application/json',
    });

    try {
      const response = await fetch('/oauth/token', {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
        credentials: 'include',
      });

      let data: OAuthTokenResponse | undefined;
      try {
        data = await response.json();
      } catch {
        data = undefined;
      }

      if (!response.ok) {
        return {
          data,
          error: data?.error_description || data?.error || response.statusText || 'Request failed',
        };
      }

      return { data };
    } catch (error) {
      return {
        error: error instanceof Error ? error.message : 'Network error',
      };
    }
  }

  async listAdminClients() {
    return this.request('/v1/admin/clients', {
      method: 'GET',
    });
  }

  async createAdminClient(data: {
    name: string;
    redirect_uri: string;
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
