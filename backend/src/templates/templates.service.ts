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
        isPublic: true,
        publishedById: true,
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

  // --- Marketplace (Milestone 14.1) ---

  /**
   * Publishes one of the org's OWN templates to the public marketplace. Scoped
   * so an org can only publish its own template; publishedById records who did.
   */
  async publish(orgId: string, templateId: string, userId: string): Promise<Template> {
    await this.findByIdScoped(templateId, orgId); // 404s another org's template
    return this.prisma.template.update({
      where: { id: templateId },
      data: { isPublic: true, publishedById: userId },
    });
  }

  /**
   * The public marketplace listing — public templates across ALL orgs
   * (cross-org discovery is the whole point), optionally filtered by a name
   * search and/or category. canvasJson is omitted from cards, as in [list].
   */
  searchMarketplace(query: {
    search?: string;
    category?: string;
  }): Promise<Omit<Template, 'canvasJson'>[]> {
    return this.prisma.template.findMany({
      where: {
        isPublic: true,
        ...(query.category ? { category: query.category } : {}),
        ...(query.search
          ? { name: { contains: query.search, mode: 'insensitive' } }
          : {}),
      },
      select: {
        id: true,
        orgId: true,
        name: true,
        category: true,
        thumbnailUrl: true,
        isPublic: true,
        publishedById: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  /**
   * Clones a PUBLIC template into the caller's org (clone-on-use). Deep-copies
   * the canvas into a brand-new row owned by [orgId] and always private
   * (isPublic=false) — so the two orgs' copies share no state, and cloning
   * never re-publishes. Only public templates are clonable; a private one 404s
   * to a different org exactly like a missing one.
   */
  async clone(orgId: string, templateId: string): Promise<Template> {
    const source = await this.prisma.template.findUnique({ where: { id: templateId } });
    if (!source || !source.isPublic) {
      throw new NotFoundException('Template not found in the marketplace.');
    }
    return this.prisma.template.create({
      data: {
        orgId,
        name: source.name,
        category: source.category,
        thumbnailUrl: source.thumbnailUrl,
        // Deep-copied so the clone shares no object reference with the source
        // — the "no shared state between org copies" guarantee, belt-and-
        // braces on top of the separate DB rows Prisma already creates.
        canvasJson: structuredClone(source.canvasJson) as Prisma.InputJsonValue,
        isPublic: false,
        publishedById: null,
      },
    });
  }
}
