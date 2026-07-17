import '../entities/social_account.dart';
import '../entities/social_platform.dart';

abstract class SocialAccountsRepository {
  Future<List<SocialAccount>> list();

  /// Returns the OAuth authorization URL to navigate the browser to.
  /// Throws for a platform that isn't connectable yet (see
  /// SocialPlatform.isConnectable) — callers should check that first and
  /// not offer a Connect button at all for those, rather than relying on
  /// this throwing as the primary guard.
  Future<String> getConnectUrl(SocialPlatform platform);

  Future<void> disconnect(String accountId);
}
