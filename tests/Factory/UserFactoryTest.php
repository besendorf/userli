<?php

namespace App\Tests\Factory;

use App\Factory\UserFactory;
use PHPUnit\Framework\TestCase;

class UserFactoryTest extends TestCase
{
    public function testCreate()
    {
        $user = UserFactory::create("UPPERCASE@example.com", "plainpassword");

        self::assertEquals("uppercase@example.com", $user->getEmail());
    }
}
