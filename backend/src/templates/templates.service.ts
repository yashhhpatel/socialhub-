import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Template } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { CreateTemplateDto } from './dto/create-template.dto';

/**
 * The org's template library (Milestone 9.4). Every query is org-scoped at
 * the database level — a template from another tenant must never be loaded,
 * the same tenant-boundary rule the rest of the app follows.
 */
@Injectable()
export class TemplatesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Gallery list — newest first. Selects everything EXCEPT canvasJson,
   * which can be large and isn't needed to render a card; the full design
   * is loaded by [findByIdScoped] only when a user starts from one.
   */
  list(orgId: string): Promise<Omit<Template, 'canvasJson'>[]> {
    return this.prisma.template.findMany({
      where: { orgId },
      select: {
        id: true,
        orgId: true,
        name: true,
        category: true,
        thumbnailUrl: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Full template, or 404 if it doesn't exist or belongs to another org. */
  async findByIdScoped(id: string, orgId: string): Promise<Template> {
    const template = await this.prisma.template.findUnique({ where: { id } });
    // Same 404 whether it's missing or another org's — never reveal that an
    // id exists in a different tenant.
    if (!template || template.orgId !== orgId) {
      throw new NotFoundException('Template not found.');
    }
    return template;
  }

  create(orgId: string, dto: CreateTemplateDto): Promise<Template> {
    return this.prisma.template.create({
      data: {
        orgId,
        name: dto.name,
        category: dto.category ?? null,
        thumbnailUrl: dto.thumbnailUrl ?? null,
        canvasJson: dto.canvasJson as unknown as Prisma.InputJsonValue,
      },
    });
  }
}
