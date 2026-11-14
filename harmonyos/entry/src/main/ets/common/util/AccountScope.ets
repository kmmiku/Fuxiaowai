/** Generation tokens invalidate writes from earlier account operations. */
export class AccountScope {
  private static revision: number = 0;
  private static owner: string = '';
  static begin(user: string): number {
    AccountScope.owner = user;
    return ++AccountScope.revision;
  }
  static token(): number { return AccountScope.revision; }
  static valid(token: number): boolean { return token === AccountScope.revision; }
  static user(): string { return AccountScope.owner; }
  static adopt(user: string): void { AccountScope.owner = user; }
  static invalidate(): void { AccountScope.owner = ''; AccountScope.revision++; }
}
