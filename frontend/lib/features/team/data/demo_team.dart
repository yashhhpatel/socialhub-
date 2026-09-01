import '../../../core/auth/app_role.dart';
import '../domain/entities/team_member.dart';

/// Sample team shown to signed-out visitors so the roster and pending-invites
/// sections look populated. Never shown once a session exists.
const demoTeamMembers = <TeamMember>[
  TeamMember(id: 'demo-u1', email: 'you@yourbrand.com', role: AppRole.owner),
  TeamMember(id: 'demo-u2', email: 'priya@yourbrand.com', role: AppRole.admin),
  TeamMember(id: 'demo-u3', email: 'marco@yourbrand.com', role: AppRole.editor),
  TeamMember(id: 'demo-u4', email: 'ana@yourbrand.com', role: AppRole.viewer),
];

const demoTeamInvites = <TeamInvite>[
  TeamInvite(
    id: 'demo-i1',
    email: 'sam@partneragency.com',
    role: AppRole.editor,
    status: 'pending',
  ),
  TeamInvite(
    id: 'demo-i2',
    email: 'jordan@yourbrand.com',
    role: AppRole.viewer,
    status: 'pending',
  ),
];
