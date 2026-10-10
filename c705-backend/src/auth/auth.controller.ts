import { Controller, Post, Delete, Body, HttpCode, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { SignupDto } from './dto/signup.dto';
import { LoginDto } from './dto/login.dto';
import { OAuthSignInDto } from './dto/oauth-signin.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { CurrentUser } from './decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('signup')
  async signup(@Body() signupDto: SignupDto): Promise<AuthResponseDto> {
    return this.authService.signup(signupDto);
  }

  @Post('login')
  @HttpCode(200) // Explicitly return 200 OK for login (not 201 Created)
  async login(@Body() loginDto: LoginDto): Promise<AuthResponseDto> {
    return this.authService.login(loginDto);
  }

  @Post('oauth/apple')
  async signInWithApple(@Body() oauthDto: OAuthSignInDto): Promise<AuthResponseDto> {
    return this.authService.signInWithOAuth(oauthDto);
  }

  @Post('oauth/google')
  async signInWithGoogle(@Body() oauthDto: OAuthSignInDto): Promise<AuthResponseDto> {
    return this.authService.signInWithOAuth(oauthDto);
  }

  @Post('update-role')
  @UseGuards(JwtAuthGuard)
  async updateRole(
    @CurrentUser() user: any,
    @Body() body: { role: string },
  ): Promise<AuthResponseDto> {
    return this.authService.updateUserRole(user.id, body.role);
  }

  @Post('update-username')
  @UseGuards(JwtAuthGuard)
  async updateUsername(
    @CurrentUser() user: any,
    @Body() body: { username: string },
  ): Promise<AuthResponseDto> {
    return this.authService.updateUsername(user.id, body.username);
  }

  @Delete('account')
  @UseGuards(JwtAuthGuard)
  async deleteAccount(@CurrentUser() user: any): Promise<{ message: string }> {
    return this.authService.deleteAccount(user.id);
  }
}
