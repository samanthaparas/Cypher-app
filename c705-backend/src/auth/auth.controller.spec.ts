import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  const authService = {
    signInWithApple: jest.fn().mockResolvedValue('apple'),
    signInWithGoogle: jest.fn().mockResolvedValue('google'),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: authService }],
    }).compile();

    controller = module.get<AuthController>(AuthController);
  });

  it('sends each OAuth route to its own provider check', async () => {
    const dto = { identityToken: 't' };
    await expect(controller.signInWithApple(dto)).resolves.toBe('apple');
    await expect(controller.signInWithGoogle(dto)).resolves.toBe('google');
    expect(authService.signInWithApple).toHaveBeenCalledWith(dto);
    expect(authService.signInWithGoogle).toHaveBeenCalledWith(dto);
  });
});
