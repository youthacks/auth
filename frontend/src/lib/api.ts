const API_URL = (import.meta.env.BACKEND_URL || 'https://auth.youthacks.org/api').replace(/\/$/, "");
interface ApiResponse<T = any> {
  data?: T;
  error?: string;
  errors?: string[];
  message?: string;
}

class ApiClient {
  private baseURL: string;
  private accessToken: string | null = null;
  private refreshToken: string | null = null;

  constructor(baseURL: string) {
    this.baseURL = baseURL;
    
    // Load tokens from localStorage if available
    if (typeof window !== 'undefined') {
      this.accessToken = localStorage.getItem('access_token');
      this.refreshToken = localStorage.getItem('refresh_token');
    }
  }

  private async request<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;
    const headers = new Headers(options.headers || {});
    headers.set('Content-Type', 'application/json');

    if (this.accessToken) {
      headers.set('Authorization', `Bearer ${this.accessToken}`);
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

  clearTokens() {
    this.accessToken = null;
    this.refreshToken = null;
    
    if (typeof window !== 'undefined') {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
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
      refresh_token: string;
    }>('/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password }),
    });

    if (response.data) {
      this.setTokens(response.data.access_token, response.data.refresh_token);
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

  getUser() {
    if (typeof window !== 'undefined') {
      const userStr = localStorage.getItem('user');
      return userStr ? JSON.parse(userStr) : null;
    }
    return null;
  }

  isAuthenticated() {
    return !!this.accessToken;
  }
}

export const api = new ApiClient(API_URL);
