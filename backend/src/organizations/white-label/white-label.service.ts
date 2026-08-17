import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../prisma/prisma.service';
import { SetWhiteLabelDto } from './dto/set-white-label.dto';

export interface WhiteLabel {
  logoUrl: string | null;
  primaryColor: string | null;
}

/**
 * Org white-label branding (Milestone 15.4). Stored on the Organization row;
 * this just reads/writes the two fields with the org boundary enforced by the
 * caller (the controller uses the JWT's org).
 */
@Injectable()
export class WhiteLabelService {
  constructor(private readonly prisma: PrismaService) {}

  async get(orgId: string): Promise<WhiteLabel> {
    const org = await this.prisma.organization.findUnique({ where: { id: orgId } });
    return {
      logoUrl: org?.whiteLabelLogoUrl ?? null,
      primaryColor: org?.whiteLabelPrimaryColor ?? null,
    };
  }

  /**
   * Partial update — only provided fields change. Passing null for a field
   * clears it (back to default branding); omitting it leaves it untouched.
   */
  async set(orgId: string, dto: SetWhiteLabelDto): Promise<WhiteLabel> {
    const org = await this.prisma.organization.update({
      where: { id: orgId },
      data: {
        ...(dto.logoUrl !== undefined ? { whiteLabelLogoUrl: dto.logoUrl } : {}),
        ...(dto.primaryColor !== undefined
          ? { whiteLabelPrimaryColor: dto.primaryColor }
          : {}),
      },
    });
    return {
      logoUrl: org.whiteLabelLogoUrl,
      primaryColor: org.whiteLabelPrimaryColor,
    };
  }
}
