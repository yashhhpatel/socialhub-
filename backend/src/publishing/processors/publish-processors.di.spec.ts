import 'reflect-metadata';

import { PublishingService } from '../publishing.service';
import { FacebookPublishProcessor } from './facebook-publish.processor';
import { InstagramPublishProcessor } from './instagram-publish.processor';
import { LinkedInPublishProcessor } from './linkedin-publish.processor';
import { ThreadsPublishProcessor } from './threads-publish.processor';
import { XPublishProcessor } from './x-publish.processor';

/**
 * Guards the NestJS inheritance-DI pitfall that once broke ALL queue
 * publishing: a `@Processor` subclass with no explicit constructor emits no
 * `design:paramtypes`, so Nest builds the worker with an undefined
 * PublishingService and every job dies with "Cannot read properties of
 * undefined (reading 'executePublish')" before the DB row is ever updated.
 *
 * Each processor must therefore declare its PublishingService dependency on
 * its OWN constructor. This asserts the metadata directly, so the regression
 * is caught without standing up the queue/DI container.
 */
describe('publish processors declare their DI dependency', () => {
  const processors = [
    InstagramPublishProcessor,
    XPublishProcessor,
    FacebookPublishProcessor,
    ThreadsPublishProcessor,
    LinkedInPublishProcessor,
  ];

  it.each(processors.map((p) => [p.name, p] as const))(
    '%s injects PublishingService (constructor paramtypes present)',
    (_name, Processor) => {
      const params = Reflect.getMetadata('design:paramtypes', Processor) as
        | unknown[]
        | undefined;
      expect(params).toBeDefined();
      expect(params).toHaveLength(1);
      expect(params?.[0]).toBe(PublishingService);
    },
  );
});
